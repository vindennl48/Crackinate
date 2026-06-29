import XCTest
@testable import Crackinate

/// Tests for PersistenceManager — UserDefaults read/write and defaults.
final class PersistenceManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults for test isolation
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("com.crackinate") || [
                SettingsKeys.screenAwakeEnabled,
                SettingsKeys.lidSleepDisabled,
                SettingsKeys.timerDuration,
                SettingsKeys.isTimerActive,
                SettingsKeys.launchAtLogin,
                SettingsKeys.dimDisplayWhenLidClosed,
                SettingsKeys.autoDisableOnThermal,
                SettingsKeys.warnOnBatteryLidClosed,
                SettingsKeys.hasCompletedSetup,
                "firstLaunchDate",
            ].contains(key) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Defaults

    func testRegisterDefaults_SetsSensibleDefaults() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        // After registering defaults, the values should be set in the registration domain
        // which means reading them from standard UserDefaults returns false/0
        let defaults = UserDefaults.standard

        // These should all be false or 0 by default
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.screenAwakeEnabled))
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.lidSleepDisabled))
        XCTAssertEqual(defaults.integer(forKey: SettingsKeys.timerDuration), 0)
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.isTimerActive))
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.launchAtLogin))
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.dimDisplayWhenLidClosed))
        XCTAssertTrue(defaults.bool(forKey: SettingsKeys.autoDisableOnThermal))
        XCTAssertTrue(defaults.bool(forKey: SettingsKeys.warnOnBatteryLidClosed))
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.hasCompletedSetup))
    }

    // MARK: - Screen Awake

    func testScreenAwakeEnabled_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertFalse(pm.screenAwakeEnabled)
        pm.screenAwakeEnabled = true
        XCTAssertTrue(pm.screenAwakeEnabled)
        pm.screenAwakeEnabled = false
        XCTAssertFalse(pm.screenAwakeEnabled)
    }

    // MARK: - Lid Sleep Disabled

    func testLidSleepDisabled_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertFalse(pm.lidSleepDisabled)
        pm.lidSleepDisabled = true
        XCTAssertTrue(pm.lidSleepDisabled)
    }

    // MARK: - Timer Duration

    func testTimerDuration_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertEqual(pm.timerDuration, 0)
        pm.timerDuration = 3600
        XCTAssertEqual(pm.timerDuration, 3600)
        pm.timerDuration = 0
        XCTAssertEqual(pm.timerDuration, 0)
    }

    // MARK: - Launch at Login

    func testLaunchAtLogin_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertFalse(pm.launchAtLogin)
        pm.launchAtLogin = true
        XCTAssertTrue(pm.launchAtLogin)
    }

    // MARK: - Display Dim

    func testDimDisplay_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertFalse(pm.dimDisplayWhenLidClosed)
        pm.dimDisplayWhenLidClosed = true
        XCTAssertTrue(pm.dimDisplayWhenLidClosed)
    }

    // MARK: - Safety Settings

    func testAutoDisableOnThermal_DefaultTrue() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()
        XCTAssertTrue(pm.autoDisableOnThermal)
        pm.autoDisableOnThermal = false
        XCTAssertFalse(pm.autoDisableOnThermal)
    }

    func testWarnOnBatteryLidClosed_DefaultTrue() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()
        XCTAssertTrue(pm.warnOnBatteryLidClosed)
        pm.warnOnBatteryLidClosed = false
        XCTAssertFalse(pm.warnOnBatteryLidClosed)
    }

    // MARK: - Setup State

    func testHasCompletedSetup() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()
        XCTAssertFalse(pm.hasCompletedSetup)
        pm.hasCompletedSetup = true
        XCTAssertTrue(pm.hasCompletedSetup)
    }

    func testFirstLaunchDate() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()
        // Explicitly clear any previously-set first launch date
        UserDefaults.standard.removeObject(forKey: "firstLaunchDate")
        XCTAssertNil(pm.firstLaunchDate)

        let now = Date()
        pm.firstLaunchDate = now
        XCTAssertEqual(pm.firstLaunchDate?.timeIntervalSince1970 ?? 0,
                       now.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    // MARK: - Persistence Across Reads

    func testValuesPersistAcrossManagerAccess() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        pm.screenAwakeEnabled = true
        pm.timerDuration = 900

        // Re-read through raw UserDefaults
        let defaults = UserDefaults.standard
        XCTAssertTrue(defaults.bool(forKey: SettingsKeys.screenAwakeEnabled))
        XCTAssertEqual(defaults.integer(forKey: SettingsKeys.timerDuration), 900)
    }

    // MARK: - isTimerActive

    func testIsTimerActive_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        XCTAssertFalse(pm.isTimerActive)
        pm.isTimerActive = true
        XCTAssertTrue(pm.isTimerActive)
    }
}
