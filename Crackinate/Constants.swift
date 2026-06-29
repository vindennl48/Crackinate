import Cocoa

/// Central location for all string constants used across the app.
enum Constants {
    /// Bundle identifier for the app.
    static let bundleIdentifier = "com.crackinate.app"

    /// Label for the LaunchAgent plist.
    static let launchAgentLabel = "com.crackinate.app"

    /// Path to the passwordless sudoers file for pmset.
    static let sudoersPath = "/etc/sudoers.d/crackinate"

    /// Path to the user LaunchAgents directory.
    static let launchAgentsDir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath

    /// Path to the LaunchAgent plist.
    static let launchAgentPlistPath = launchAgentsDir + "/com.crackinate.app.plist"
}

/// UserDefaults keys — use these instead of raw strings to avoid typos.
enum SettingsKeys {
    // Toggle states
    static let screenAwakeEnabled = "screenAwakeEnabled"
    static let lidSleepDisabled = "lidSleepDisabled"

    // Timer
    static let timerDuration = "timerDuration"          // seconds; 0 = forever
    static let isTimerActive = "isTimerActive"

    // General
    static let launchAtLogin = "launchAtLogin"

    // Display
    static let dimDisplayWhenLidClosed = "dimDisplayWhenLidClosed"

    // Safety
    static let autoDisableOnThermal = "autoDisableOnThermal"
    static let warnOnBatteryLidClosed = "warnOnBatteryLidClosed"

    // Misc
    static let hasCompletedSetup = "hasCompletedSetup"
    static let firstLaunchDate = "firstLaunchDate"
}
