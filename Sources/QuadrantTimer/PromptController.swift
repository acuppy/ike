import AppKit
import SwiftUI

@MainActor
final class PromptController {
    private var panel: NSPanel?
    private(set) var lastQuadrant: Quadrant?
    // The most recently submitted note. When the next prompt's selected
    // quadrant matches lastQuadrant, this gets pre-filled so the user
    // doesn't have to retype "still doing X" every block.
    private(set) var lastNote: String = ""

    // Calendar context (event titles overlapping each block) lights up the
    // prompt and pre-fills its note. Optional so the coordinator can wire
    // it lazily and the controller stays testable without EventKit.
    var calendarStore: CalendarStore?

    var onResolved: ((Quadrant, String, Bool, Date, Date) -> Void)?

    func present(blockStart: Date, blockEnd: Date) {
        guard panel == nil else { return }

        NSSound(named: "Glass")?.play()

        let calendarContext = calendarStore?.context(for: blockStart, end: blockEnd)

        let view = PromptView(
            lastQuadrant: lastQuadrant,
            lastNote: lastNote,
            calendarContext: calendarContext,
            onSubmit: { [weak self] q, note in
                self?.resolve(quadrant: q, note: note, auto: false, start: blockStart, end: blockEnd)
            },
            onAutoLog: { [weak self] q, note in
                self?.resolve(quadrant: q, note: note, auto: true, start: blockStart, end: blockEnd)
            }
        )

        let host = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
            styleMask: [.titled, .closable, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Ike"
        panel.contentViewController = host
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.center()

        self.panel = panel
    }

    // Tear down an open prompt without logging anything. Used when the user
    // steps away (sleep/lock): the away handler will account for that span
    // instead, and tearing the panel down cancels its auto-log countdown so
    // it can't fire a stale block on wake.
    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func resolve(quadrant: Quadrant, note: String, auto: Bool, start: Date, end: Date) {
        guard panel != nil else { return }
        panel?.orderOut(nil)
        panel = nil
        lastQuadrant = quadrant
        lastNote = note
        onResolved?(quadrant, note, auto, start, end)
    }
}
