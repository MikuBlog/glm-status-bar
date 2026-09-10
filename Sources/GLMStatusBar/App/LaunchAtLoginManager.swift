import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    /// Whether the app is currently registered as a login item.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register/unregister the app as a login item.
    /// Returns false when the system rejects the change (e.g. bare binary run
    /// via `swift run` instead of the installed .app bundle).
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
