import Foundation

/// Wrapper around `UserDefaults` with typed accessors for every setting.
/// Call `registerDefaults()` once at app launch.
final class PersistenceManager {

    // MARK: - Singleton

    static let shared = PersistenceManager()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - Register Defaults

    func registerDefaults() {
        defaults.register(defaults: [
            SettingsKeys.screenAwakeEnabled: false,
            SettingsKeys.lidSleepDisabled: false,
            SettingsKeys.timerDuration: 0,            // 0 = forever
            SettingsKeys.isTimerActive: false,
            SettingsKeys.launchAtLogin: false,
            SettingsKeys.dimDisplayWhenLidClosed: false,
            SettingsKeys.autoDisableOnThermal: true,
            SettingsKeys.warnOnBatteryLidClosed: true,
            SettingsKeys.hasCompletedSetup: false,
        ])
    }

    // MARK: - Toggle States

    var screenAwakeEnabled: Bool {
        get { defaults.bool(forKey: SettingsKeys.screenAwakeEnabled) }
        set { defaults.set(newValue, forKey: SettingsKeys.screenAwakeEnabled) }
    }

    var lidSleepDisabled: Bool {
        get { defaults.bool(forKey: SettingsKeys.lidSleepDisabled) }
        set { defaults.set(newValue, forKey: SettingsKeys.lidSleepDisabled) }
    }

    // MARK: - Timer

    /// Timer duration in seconds. 0 means "forever" (no timer).
    var timerDuration: Int {
        get { defaults.integer(forKey: SettingsKeys.timerDuration) }
        set { defaults.set(newValue, forKey: SettingsKeys.timerDuration) }
    }

    var isTimerActive: Bool {
        get { defaults.bool(forKey: SettingsKeys.isTimerActive) }
        set { defaults.set(newValue, forKey: SettingsKeys.isTimerActive) }
    }

    // MARK: - General

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: SettingsKeys.launchAtLogin) }
        set { defaults.set(newValue, forKey: SettingsKeys.launchAtLogin) }
    }

    // MARK: - Display

    var dimDisplayWhenLidClosed: Bool {
        get { defaults.bool(forKey: SettingsKeys.dimDisplayWhenLidClosed) }
        set { defaults.set(newValue, forKey: SettingsKeys.dimDisplayWhenLidClosed) }
    }

    // MARK: - Safety

    var autoDisableOnThermal: Bool {
        get { defaults.bool(forKey: SettingsKeys.autoDisableOnThermal) }
        set { defaults.set(newValue, forKey: SettingsKeys.autoDisableOnThermal) }
    }

    var warnOnBatteryLidClosed: Bool {
        get { defaults.bool(forKey: SettingsKeys.warnOnBatteryLidClosed) }
        set { defaults.set(newValue, forKey: SettingsKeys.warnOnBatteryLidClosed) }
    }

    // MARK: - Setup

    var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: SettingsKeys.hasCompletedSetup) }
        set { defaults.set(newValue, forKey: SettingsKeys.hasCompletedSetup) }
    }

    var firstLaunchDate: Date? {
        get { defaults.object(forKey: SettingsKeys.firstLaunchDate) as? Date }
        set { defaults.set(newValue, forKey: SettingsKeys.firstLaunchDate) }
    }
}
