import AppKit
import SwiftUI

@MainActor
final class BreakPromptController {
    private var panel: NSPanel?

    var onContinue: (() -> Void)?
    var onEnd: (() -> Void)?

    func present(elapsed: TimeInterval) {
        guard panel == nil else { return }

        NSSound(named: "Glass")?.play()

        let view = BreakPromptView(
            elapsed: elapsed,
            onContinue: { [weak self] in self?.resolve(continue: true) },
            onEnd:      { [weak self] in self?.resolve(continue: false) }
        )

        let host = NSHostingController(rootView: view)
        host.sizingOptions = [.preferredContentSize]

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .closable, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "On Break"
        panel.contentViewController = host
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        guard panel != nil else { return }
        panel?.orderOut(nil)
        panel = nil
    }

    private func resolve(continue shouldContinue: Bool) {
        guard panel != nil else { return }
        panel?.orderOut(nil)
        panel = nil
        if shouldContinue {
            onContinue?()
        } else {
            onEnd?()
        }
    }
}
