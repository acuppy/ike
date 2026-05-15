import AppKit
import SwiftUI

@MainActor
final class PromptController {
    private var panel: NSPanel?
    private(set) var lastQuadrant: Quadrant?

    var onResolved: ((Quadrant, String, Bool, Date, Date) -> Void)?

    func present(blockStart: Date, blockEnd: Date) {
        guard panel == nil else { return }

        NSSound(named: "Glass")?.play()

        let view = PromptView(
            lastQuadrant: lastQuadrant,
            onSubmit: { [weak self] q, note in
                self?.resolve(quadrant: q, note: note, auto: false, start: blockStart, end: blockEnd)
            },
            onAutoLog: { [weak self] q in
                self?.resolve(quadrant: q, note: "", auto: true, start: blockStart, end: blockEnd)
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

    private func resolve(quadrant: Quadrant, note: String, auto: Bool, start: Date, end: Date) {
        guard panel != nil else { return }
        panel?.orderOut(nil)
        panel = nil
        lastQuadrant = quadrant
        onResolved?(quadrant, note, auto, start, end)
    }
}
