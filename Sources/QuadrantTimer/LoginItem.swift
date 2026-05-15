import Foundation
import ServiceManagement

@MainActor
@Observable
final class LoginItem {
    var isEnabled: Bool

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            NSLog("LoginItem toggle failed: \(error)")
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
