import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct QuadrantTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
    let weeklyWindow = WeeklyWindowController()
    let scheduleSettings = ScheduleSettings()
    let scheduleMonitor: ScheduleMonitor
    let preferencesWindow = PreferencesWindowController()
    let breakState = BreakState()
    let breakPrompt = BreakPromptController()
    let loginItem = LoginItem()
    let serverSettings = ServerSettings()
    let blockSyncer: BlockSyncer
    let calendarStore = CalendarStore.shared
    let presence = PresenceMonitor()

    // Absences shorter than this (a quick screen lock, a glance away) are
    // ignored — we just resume rather than logging an away block.
    private static let minimumAwayInterval: TimeInterval = 60

    // Wall-clock moment the user stepped away (sleep/lock). nil while present.
    // A single value dedupes the lock+sleep / wake+unlock pairs.
    private var awayStartedAt: Date?

    init() {
        scheduleMonitor = ScheduleMonitor(settings: scheduleSettings)
        blockSyncer = BlockSyncer(settings: serverSettings)
        prompt.calendarStore = calendarStore

        URLEventBridge.shared.setHandler { [weak self] url in
            self?.handleURL(url)
        }

        timer.blockDurationProvider = { [scheduleSettings] in
            TimeInterval(max(1, scheduleSettings.blockDurationMinutes) * 60)
        }

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
        presence.onAway = { [weak self] in self?.handleWentAway() }
        presence.onReturn = { [weak self] in self?.handleReturned() }

        registerGlobalShortcuts()
        scheduleMonitor.start()
        presence.start()

        if scheduleMonitor.isActive {
            timer.start()
        }

        // Push any locally-logged blocks that haven't been synced yet.
        blockSyncer.sync()
    }

    // Handles ike://connected?token=…&email=… from the server's /connect
    // redirect. Anything else gets ignored.
    func handleURL(_ url: URL) {
        guard url.scheme == "ike", url.host == "connected" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let token = items.first(where: { $0.name == "token" })?.value,
              let email = items.first(where: { $0.name == "email" })?.value else { return }
        serverSettings.connect(token: token, email: email)
        blockSyncer.forgetSyncedIds()  // fresh server / fresh account → repush everything
        blockSyncer.sync()
        showPreferences()
    }

    func openServerSignIn() {
        guard let url = serverSettings.connectURL else { return }
        NSWorkspace.shared.open(url)
    }

    func disconnectFromServer() {
        serverSettings.disconnect()
        blockSyncer.forgetSyncedIds()
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
        weeklyWindow.dismiss()
        logWindow.present(viewModel: logViewModel, anchor: statusBarRect())
    }

    func showWeeklyWindow() {
        logWindow.dismiss()
        weeklyWindow.show(anchor: statusBarRect())
    }

    private func statusBarRect() -> NSRect? {
        NSApp.windows.first { NSStringFromClass(type(of: $0)) == "NSStatusBarWindow" }?.frame
    }

    func showPreferences() {
        preferencesWindow.present(
            settings: scheduleSettings,
            loginItem: loginItem,
            serverSettings: serverSettings,
            blockSyncer: blockSyncer,
            calendarStore: calendarStore,
            onConnect: { [weak self] in self?.openServerSignIn() },
            onDisconnect: { [weak self] in self?.disconnectFromServer() }
        )
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

    // The Mac slept or the screen locked. Freeze the timer and drop any open
    // prompt so its countdown can't auto-log a stale block on wake; the away
    // span gets reconciled in handleReturned.
    private func handleWentAway() {
        guard scheduleMonitor.isActive, !breakState.isActive, awayStartedAt == nil else { return }
        awayStartedAt = Date()
        prompt.dismiss()
        timer.pause()
    }

    // Back from sleep/lock. If the absence was long enough, log the gap as one
    // entry spanning the interrupted block so the timeline stays continuous —
    // typed by the awayLogging preference — then start a fresh block.
    private func handleReturned() {
        guard let awayStart = awayStartedAt else { return }
        awayStartedAt = nil

        guard Date().timeIntervalSince(awayStart) >= Self.minimumAwayInterval else {
            timer.resume() // brief lock — pick up where we left off
            return
        }
        guard scheduleMonitor.isActive else {
            timer.stop() // came back off the clock; nothing to log
            return
        }

        logger.append(awayEntry(start: timer.blockStartedAt, end: Date()))
        logViewModel.reload()
        timer.resetBlock()
    }

    private func awayEntry(start: Date, end: Date) -> BlockEntry {
        switch scheduleSettings.awayLogging {
        case .continuation:
            BlockEntry(start: start, end: end, quadrant: prompt.lastQuadrant ?? .q2, note: prompt.lastNote, auto: true)
        case .breakTime:
            BlockEntry(start: start, end: end, quadrant: .breakTime, note: "", auto: true)
        }
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
        if coordinator.serverSettings.isConnected {
            let syncDidFail = coordinator.blockSyncer.syncDidFail
            Button {
                coordinator.showPreferences()
            } label: {
                Label {
                    Text("Signed in as \(coordinator.serverSettings.connectedEmail ?? "")")
                } icon: {
                    Image(systemName: syncDidFail ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(syncDidFail ? .orange : .green)
                }
            }
            if syncDidFail {
                Button("Retry sync") {
                    coordinator.blockSyncer.sync()
                }
            }
        } else {
            Button {
                coordinator.openServerSignIn()
            } label: {
                Label {
                    Text("Not connected")
                } icon: {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        Divider()
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
        Button {
            coordinator.showWeeklyWindow()
        } label: {
            Label {
                Text("View weekly trends…")
            } icon: {
                Image(systemName: "chart.bar")
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
