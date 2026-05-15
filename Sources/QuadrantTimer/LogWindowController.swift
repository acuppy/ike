import AppKit
import SwiftUI

@MainActor
final class LogWindowController {
    private var window: NSWindow?
    private var delegate: WindowDelegate?

    func present(viewModel: LogViewModel) {
        viewModel.reload()

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: LogView(viewModel: viewModel))
        host.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: host)
        window.title = "Today's Log"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = WindowDelegate { [weak self] in
            self?.window = nil
            self?.delegate = nil
        }
        window.delegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.delegate = delegate
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
