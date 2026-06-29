import Foundation
import ServiceManagement

/// Manages the LaunchAgent plist for auto-revive (restart on crash)
/// and SMAppService registration for launch at login.
final class LaunchAgentManager {
    static let shared = LaunchAgentManager()
    private init() {}

    // MARK: - SMAppService (Launch at Login)

    /// macOS 13+ native login item registration.
    var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLoginItemEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        print("[Crackinate] Login item \(enabled ? "registered" : "unregistered")")
    }

    // MARK: - LaunchAgent (Auto-Revive on Crash)

    /// Install a user LaunchAgent that restarts the app if it crashes.
    /// Clean exit (0) will NOT trigger a restart.
    func installLaunchAgent() throws {
        let plist = launchAgentPlist()
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        // Ensure directory exists
        let dir = (Constants.launchAgentPlistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )

        try plistData.write(to: URL(fileURLWithPath: Constants.launchAgentPlistPath))

        // Load into launchd
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", Constants.launchAgentPlistPath]
        try task.run()
        task.waitUntilExit()

        print("[Crackinate] LaunchAgent installed and loaded")
    }

    /// Remove the LaunchAgent.
    func uninstallLaunchAgent() {
        // Unload from launchd
        let unloadTask = Process()
        unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadTask.arguments = ["unload", Constants.launchAgentPlistPath]
        try? unloadTask.run()
        unloadTask.waitUntilExit()

        // Delete the plist
        try? FileManager.default.removeItem(atPath: Constants.launchAgentPlistPath)

        print("[Crackinate] LaunchAgent uninstalled")
    }

    /// Check if the LaunchAgent plist exists on disk.
    var isLaunchAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: Constants.launchAgentPlistPath)
    }

    /// Verify the LaunchAgent ProgramArguments points to the current app path.
    /// If the user moved the app, update the plist.
    func validateLaunchAgentPath() {
        guard isLaunchAgentInstalled else { return }
        guard let currentPath = Bundle.main.executablePath else { return }

        // Read existing plist
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Constants.launchAgentPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String],
              let existingPath = args.first else {
            return
        }

        if existingPath != currentPath {
            print("[Crackinate] App moved — updating LaunchAgent path from \(existingPath) to \(currentPath)")
            // Re-install with new path
            try? installLaunchAgent()
        }
    }

    /// Enable both SMAppService and LaunchAgent.
    func enableAll() throws {
        try setLoginItemEnabled(true)
        try installLaunchAgent()
        PersistenceManager.shared.launchAtLogin = true
    }

    /// Disable both SMAppService and LaunchAgent.
    func disableAll() {
        try? setLoginItemEnabled(false)
        uninstallLaunchAgent()
        PersistenceManager.shared.launchAtLogin = false
    }

    // MARK: - Private

    private func launchAgentPlist() -> [String: Any] {
        let appPath = Bundle.main.executablePath ?? "/Applications/Crackinate.app/Contents/MacOS/Crackinate"
        return [
            "Label": Constants.launchAgentLabel,
            "ProgramArguments": [appPath],
            "RunAtLoad": true,
            "KeepAlive": [
                "SuccessfulExit": false
            ],
            "ThrottleInterval": 5,
        ]
    }
}
