import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let configuredKey = "launchAtLoginConfigured"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(true, forKey: configuredKey)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Could not change launch at login: \(error)")
        }
    }

    /// Turned on once on first launch; after that the user's choice sticks.
    /// Debug builds skip this so the login item never points at a build folder.
    static func enableOnFirstLaunch() {
        #if !DEBUG
        guard !UserDefaults.standard.bool(forKey: configuredKey) else { return }
        setEnabled(true)
        #endif
    }
}
