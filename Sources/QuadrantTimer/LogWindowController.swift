import AppKit
import SwiftUI

@MainActor
final class LogWindowController {
    private var window: NSWindow?
    private var delegate: WindowDelegate?

    func present(viewModel: LogViewModel, anchor: NSRect? = nil) {
        viewModel.reload()

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            position(window, anchor: anchor)
            return
        }

        let host = NSHostingController(rootView: LogView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Today's Log"
        window.isReleasedWhenClosed = false
        window.contentViewController = host

        let delegate = WindowDelegate { [weak self] in
            self?.window = nil
            self?.delegate = nil
        }
        window.delegate = delegate
        self.window = window
        self.delegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        position(window, anchor: anchor)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func position(_ window: NSWindow, anchor: NSRect?) {
        guard let anchor, let screen = NSScreen.main else {
            window.center()
            return
        }
        let w = window.frame.width
        let h = window.frame.height
        let rawX = anchor.midX - w / 2
        let x = rawX < screen.frame.minX ? screen.frame.minX
              : rawX > screen.frame.maxX - w ? screen.frame.maxX - w
              : rawX
        let y = anchor.minY - h
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
