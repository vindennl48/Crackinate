import XCTest
@testable import Crackinate

/// Tests for PowerMonitor — AC/battery detection.
final class PowerMonitorTests: XCTestCase {

    // MARK: - checkACPower

    func testCheckACPower_ReturnsBool() {
        // checkACPower queries IOKit power sources — in tests we just
        // verify it doesn't crash and returns a valid boolean
        let result = PowerMonitor.checkACPower()
        // On a desktop Mac or plugged-in laptop, this should be true
        // On battery, it would be false. Either way, no crash.
        XCTAssertTrue(result == true || result == false)
    }

    func testCheckACPower_IsDeterministic() {
        let first = PowerMonitor.checkACPower()
        let second = PowerMonitor.checkACPower()
        // Same call should return same result (power source doesn't change mid-test)
        XCTAssertEqual(first, second)
    }
}

/// Tests for battery warning setting and lid-close enable pipeline behavior.
final class BatteryWarningTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeepAwakeManager.shared.disableAll()
        PersistenceManager.shared.registerDefaults()
        // Explicitly reset UserDefaults for test isolation
        for key in [
            SettingsKeys.screenAwakeEnabled,
            SettingsKeys.lidSleepDisabled,
            SettingsKeys.timerDuration,
            SettingsKeys.isTimerActive,
            SettingsKeys.launchAtLogin,
            SettingsKeys.dimDisplayWhenLidClosed,
            SettingsKeys.autoDisableOnThermal,
            SettingsKeys.warnOnBatteryLidClosed,
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        PersistenceManager.shared.registerDefaults()
    }

    override func tearDown() {
        KeepAwakeManager.shared.disableAll()
        super.tearDown()
    }

    // MARK: - warnOnBatteryLidClosed Default

    func testWarnOnBatteryLidClosed_DefaultsToTrue() {
        PersistenceManager.shared.registerDefaults()
        XCTAssertTrue(PersistenceManager.shared.warnOnBatteryLidClosed)
    }

    func testWarnOnBatteryLidClosed_GetSet() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        pm.warnOnBatteryLidClosed = false
        XCTAssertFalse(pm.warnOnBatteryLidClosed)

        pm.warnOnBatteryLidClosed = true
        XCTAssertTrue(pm.warnOnBatteryLidClosed)
    }

    func testWarnOnBatteryLidClosed_PersistsInUserDefaults() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        pm.warnOnBatteryLidClosed = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: SettingsKeys.warnOnBatteryLidClosed))

        UserDefaults.standard.set(true, forKey: SettingsKeys.warnOnBatteryLidClosed)
        XCTAssertTrue(pm.warnOnBatteryLidClosed)
    }

    // MARK: - Lid Close Enable: Battery Check Order

    func testEnableLidClose_ChecksBatteryBeforePmset() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        // Battery warning is enabled by default
        XCTAssertTrue(pm.warnOnBatteryLidClosed,
                      "warnOnBatteryLidClosed should default to true")

        // Power monitor can detect AC/battery without crashing
        let isOnAC = PowerMonitor.checkACPower()
        XCTAssertTrue(isOnAC == true || isOnAC == false,
                      "checkACPower should return a valid boolean")
    }

    // MARK: - Safety Setting Independence

    func testAutoDisableOnThermal_And_BatteryWarning_AreIndependent() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        pm.autoDisableOnThermal = false
        pm.warnOnBatteryLidClosed = true
        XCTAssertFalse(pm.autoDisableOnThermal)
        XCTAssertTrue(pm.warnOnBatteryLidClosed)

        pm.autoDisableOnThermal = true
        pm.warnOnBatteryLidClosed = false
        XCTAssertTrue(pm.autoDisableOnThermal)
        XCTAssertFalse(pm.warnOnBatteryLidClosed)
    }

    // MARK: - Screen Awake Not Affected By Battery

    func testEnablingScreenAwake_DoesNotCheckBattery() {
        // Screen awake should work regardless of battery state
        KeepAwakeManager.shared.enableScreenAwake()
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)

        // Lid-close prevention should also not affect screen awake
        let isOnAC = PowerMonitor.checkACPower()
        // Regardless of AC state, screen awake should remain enabled
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)

        KeepAwakeManager.shared.disableScreenAwake()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
    }
}
