import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private var delegate: PrefsWindowDelegate?

    func present(settings: ScheduleSettings) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: PreferencesView(settings: settings))
        host.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: host)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = PrefsWindowDelegate { [weak self] in
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

private final class PrefsWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
