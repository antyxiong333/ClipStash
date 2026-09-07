import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Off"
        case .requiresApproval:
            return "Needs approval in System Settings"
        case .notFound:
            return "App bundle not found"
        @unknown default:
            return "Unknown"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
