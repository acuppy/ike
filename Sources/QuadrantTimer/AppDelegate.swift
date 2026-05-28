import AppKit
import Foundation

// Routes ike:// callbacks from the OS into the SwiftUI app. We use the
// classic Apple Event handler (not SwiftUI's onOpenURL) because menu-bar-
// only apps without a window scene don't reliably receive URL events
// through the SwiftUI path.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc nonisolated func handleURLEvent(_ event: NSAppleEventDescriptor, withReply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        Task { @MainActor in
            URLEventBridge.shared.dispatch(url)
        }
    }
}

// Indirection so the SwiftUI side can register a handler without holding a
// reference to AppDelegate (and vice versa). AppCoordinator subscribes once
// at startup.
@MainActor
final class URLEventBridge {
    static let shared = URLEventBridge()

    private var handler: ((URL) -> Void)?
    private var pending: [URL] = []

    func setHandler(_ handler: @escaping (URL) -> Void) {
        self.handler = handler
        let queued = pending
        pending.removeAll()
        queued.forEach(handler)
    }

    func dispatch(_ url: URL) {
        if let handler {
            handler(url)
        } else {
            // The URL can arrive before SwiftUI finishes wiring; queue it.
            pending.append(url)
        }
    }
}
