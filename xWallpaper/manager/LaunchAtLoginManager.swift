import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let preferenceKey = "launchOnStartup"

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func syncWithStoredPreference() {
        setEnabled(UserDefaults.standard.bool(forKey: preferenceKey))
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return true }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status != .notRegistered else { return true }
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
            return false
        }
    }
}
