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
        window.setFrameAutosaveName("QuadrantTimer.weekly")
        super.init(window: window)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        viewModel.reload()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
