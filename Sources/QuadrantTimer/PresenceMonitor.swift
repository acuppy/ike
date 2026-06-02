import AppKit

// Watches for the user leaving and returning to the machine — system sleep
// and screen lock on the way out, wake and unlock on the way back. The
// coordinator uses these to reconcile the wall-clock time that passes while
// the timer is frozen (it doesn't tick during sleep), instead of silently
// dropping it.
//
// Lock and sleep often fire together (lock, then sleep), as do wake and
// unlock; callers should treat onAway/onReturn as idempotent edges, not
// one-to-one events. All four notifications are delivered on the main thread.
@MainActor
final class PresenceMonitor {
    var onAway: (() -> Void)?
    var onReturn: (() -> Void)?

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(wentAway), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(returned), name: NSWorkspace.didWakeNotification, object: nil)

        // Screen lock/unlock have no public constants; these distributed
        // notification names are long-standing and widely used.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(wentAway), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(returned), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func wentAway() { onAway?() }
    @objc private func returned() { onReturn?() }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
