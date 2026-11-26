import CharlPlatform
import Foundation
import ServiceManagement

public final class MacLoginItem: LoginItemService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        Log.app.notice("launchAtLogin set=\(enabled) status=\(String(describing: SMAppService.mainApp.status), privacy: .public)")
    }
}