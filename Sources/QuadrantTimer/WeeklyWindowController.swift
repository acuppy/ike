import AppKit
import SwiftUI

class WeeklyWindowController: NSWindowController {
    private(set) var viewModel: WeeklyViewModel

    init() {
        let model = WeeklyViewModel()
        self.viewModel = model
        let window = NSWindow(contentViewController: NSHostingController(rootView: WeeklyView(viewModel: model)))
        window.title = "Weekly Trends"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func dismiss() {
        window?.orderOut(nil)
    }

    func show(anchor: NSRect? = nil) {
        viewModel.reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        if let anchor, let screen = NSScreen.main, let window {
            let w = window.frame.width
            let h = window.frame.height
            let rawX = anchor.midX - w / 2
            let x = rawX < screen.frame.minX ? screen.frame.minX
                  : rawX > screen.frame.maxX - w ? screen.frame.maxX - w
                  : rawX
            window.setFrameOrigin(NSPoint(x: x, y: anchor.minY - h))
        }
    }
}
