import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct QuadrantTimerApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuView(coordinator: coordinator)
        } label: {
            MenuBarLabel(coordinator: coordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarLabel: View {
    let coordinator: AppCoordinator

    var body: some View {
        if coordinator.breakState.isActive {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer")
                    .foregroundStyle(.blue)
                Text(coordinator.breakState.formattedElapsed)
                    .monospacedDigit()
            }
        } else if coordinator.scheduleMonitor.isActive {
            HStack(spacing: 4) {
                Image(systemName: coordinator.timer.isPaused ? "pause.circle" : "square.grid.2x2")
                Text(coordinator.timer.formattedRemaining)
                    .monospacedDigit()
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz")
                if let next = coordinator.scheduleMonitor.nextActivation {
                    Text(formatNext(next))
                        .monospacedDigit()
                }
            }
        }
    }

    private func formatNext(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = .current
        if cal.isDateInToday(date) {
            f.setLocalizedDateFormatFromTemplate("jmm")
        } else {
            f.setLocalizedDateFormatFromTemplate("EEEjmm")
        }
        return f.string(from: date)
    }
}

@MainActor
@Observable
final class AppCoordinator {
    let timer = TimerEngine()
    let prompt = PromptController()
    let logger = BlockLogger.shared
    let logViewModel = LogViewModel()
    let logWindow = LogWindowController()
    let scheduleSettings = ScheduleSettings()
    let scheduleMonitor: ScheduleMonitor
    let preferencesWindow = PreferencesWindowController()
    let breakState = BreakState()
    let breakPrompt = BreakPromptController()

    init() {
        scheduleMonitor = ScheduleMonitor(settings: scheduleSettings)

        timer.onBlockComplete = { [weak self] start, end in
            self?.handleBlockComplete(start: start, end: end)
        }
        prompt.onResolved = { [weak self] quadrant, note, auto, start, end in
            self?.handleResolved(quadrant: quadrant, note: note, auto: auto, start: start, end: end)
        }
        scheduleMonitor.onActivate = { [weak self] in
            self?.handleScheduleActivate()
        }
        scheduleMonitor.onDeactivate = { [weak self] in
            self?.handleScheduleDeactivate()
        }
        breakState.onEnd = { [weak self] start, end in
            self?.logBreakEntry(start: start, end: end)
        }
        breakPrompt.onContinue = { [weak self] in
            self?.continueBreak()
        }
        breakPrompt.onEnd = { [weak self] in
            self?.endBreak()
        }

        registerGlobalShortcuts()
        scheduleMonitor.start()

        if scheduleMonitor.isActive {
            timer.start()
        }
    }

    func logNowAndRestart() {
        let end = Date()
        handleBlockComplete(start: timer.blockStartedAt, end: end)
    }

    func logAndReset(_ quadrant: Quadrant) {
        let entry = BlockEntry(
            start: timer.blockStartedAt,
            end: Date(),
            quadrant: quadrant,
            note: "",
            auto: false
        )
        logger.append(entry)
        logViewModel.reload()
        timer.resetBlock()
    }

    func showLogWindow() {
        logWindow.present(viewModel: logViewModel)
    }

    func showPreferences() {
        preferencesWindow.present(settings: scheduleSettings)
    }

    func toggleWorkOverride() {
        if scheduleSettings.workOverrideUntil != nil {
            scheduleMonitor.clearWorkOverride()
        } else {
            scheduleMonitor.enableWorkOverrideUntilEndOfDay()
        }
    }

    func endDayNow() {
        scheduleMonitor.endDayUntilMidnight()
    }

    func confirmEndDay() {
        let alert = NSAlert()
        alert.messageText = "End the day?"
        alert.informativeText = "The timer will stop and prompts won't fire until tomorrow's schedule."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "End day")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            endDayNow()
        }
    }

    func startDayAgain() {
        scheduleMonitor.clearEndDay()
    }

    func toggleBreak() {
        if breakState.isActive {
            endBreak()
        } else {
            startBreak()
        }
    }

    func startBreak() {
        guard !breakState.isActive else { return }
        breakState.start()
        timer.resetBlock()
    }

    func endBreak() {
        guard breakState.isActive else { return }
        breakPrompt.dismiss()
        breakState.end()
        if scheduleMonitor.isActive {
            timer.resetBlock()
        } else {
            timer.stop()
        }
    }

    func revealLogInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([logger.fileURL])
    }

    private func registerGlobalShortcuts() {
        for q in Quadrant.working {
            guard let name = q.shortcutName else { continue }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.logAndReset(q)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleBreak) { [weak self] in
            self?.toggleBreak()
        }
    }

    private func handleBlockComplete(start: Date, end: Date) {
        timer.pause()
        if breakState.isActive {
            breakPrompt.present(elapsed: breakState.elapsed)
        } else {
            prompt.present(blockStart: start, blockEnd: end)
        }
    }

    private func handleResolved(quadrant: Quadrant, note: String, auto: Bool, start: Date, end: Date) {
        let entry = BlockEntry(start: start, end: end, quadrant: quadrant, note: note, auto: auto)
        logger.append(entry)
        logViewModel.reload()
        timer.resetBlock()
    }

    private func continueBreak() {
        timer.resetBlock()
    }

    private func logBreakEntry(start: Date, end: Date) {
        let entry = BlockEntry(start: start, end: end, quadrant: .breakTime, note: "", auto: false)
        logger.append(entry)
        logViewModel.reload()
    }

    private func handleScheduleActivate() {
        timer.start()
    }

    private func handleScheduleDeactivate() {
        if breakState.isActive {
            breakPrompt.dismiss()
            breakState.end()
        }
        timer.stop()
    }
}

struct MenuView: View {
    let coordinator: AppCoordinator

    var body: some View {
        if coordinator.scheduleSettings.endDayUntil != nil {
            Button("Start day (resume schedule)") {
                coordinator.startDayAgain()
            }
            Divider()
        } else if !coordinator.scheduleMonitor.isActive {
            Button(coordinator.scheduleSettings.workOverrideUntil == nil
                   ? "Work now (override schedule until midnight)"
                   : "End work override") {
                coordinator.toggleWorkOverride()
            }
            Divider()
        }
        Button {
            coordinator.toggleBreak()
        } label: {
            Label {
                Text(coordinator.breakState.isActive ? "End break" : "Start break")
            } icon: {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.blue)
            }
        }
        .keyboardShortcut("0", modifiers: [.command, .control, .option])
        Divider()
        ForEach(Quadrant.working) { q in
            Button {
                coordinator.logAndReset(q)
            } label: {
                Label {
                    Text(q.label)
                } icon: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(q.color)
                }
            }
            .keyboardShortcut(
                KeyEquivalent(Character("\(q.shortcutDigit)")),
                modifiers: [.command, .control, .option]
            )
            .disabled(coordinator.breakState.isActive)
        }
        Button {
            coordinator.logNowAndRestart()
        } label: {
            Label {
                Text("Log details…")
            } icon: {
                Image(systemName: "square.and.pencil")
            }
        }
        .disabled(!coordinator.scheduleMonitor.isActive || coordinator.breakState.isActive)
        Divider()
        Button {
            coordinator.confirmEndDay()
        } label: {
            Label {
                Text("End day…")
            } icon: {
                Image(systemName: "moon.zzz")
            }
        }
        .disabled(!coordinator.scheduleMonitor.isActive || coordinator.scheduleSettings.endDayUntil != nil)
        Divider()
        Button {
            coordinator.showLogWindow()
        } label: {
            Label {
                Text("View today's log…")
            } icon: {
                Image(systemName: "chart.bar.xaxis")
            }
        }
        Button("Reveal log in Finder…") {
            coordinator.revealLogInFinder()
        }
        Divider()
        Button("Preferences…") {
            coordinator.showPreferences()
        }
        .keyboardShortcut(",")
        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
