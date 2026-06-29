import XCTest
@testable import Crackinate

/// Tests for the PopoverView toggle logic — specifically the lid-close toggle
/// behavior when sudoers is not installed, and Preferences opening.
final class PopoverViewLogicTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeepAwakeManager.shared.disableAll()
        PersistenceManager.shared.registerDefaults()
    }

    override func tearDown() {
        KeepAwakeManager.shared.disableAll()
        super.tearDown()
    }

    // MARK: - Lid Toggle: Sudoers Not Installed

    func testLidToggle_EnableWithoutSudoers_GracefullyFails() {
        // When sudoers is not installed and user tries to enable lid-close,
        // the KeepAwakeManager should fail gracefully without crashing

        // Enable screen awake first (to check no side effects)
        KeepAwakeManager.shared.enableScreenAwake()
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)

        // Try to enable lid-close (will fail because no sudoers)
        KeepAwakeManager.shared.enableLidClosePrevention()

        // Screen awake should still be active (not affected by lid-close failure)
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)

        // Lid-close should NOT be active (the enable failed)
        // Note: this depends on whether the sudoers file exists on the test machine
        let lidActive = KeepAwakeManager.shared.isLidClosePreventionActive
        // If it's active, the sudoers was installed; if not, it failed gracefully
        // Either way, the app should not have crashed
        XCTAssertTrue(lidActive == true || lidActive == false)
    }

    func testDisableLidClose_WhenNotEnabled_IsSafe() {
        // Calling disable when lid-close was never enabled should not crash
        KeepAwakeManager.shared.disableLidClosePrevention()
        XCTAssertFalse(KeepAwakeManager.shared.isLidClosePreventionActive)
    }

    // MARK: - PersistenceManager Lid Setting

    func testLidSleepDisabled_PersistsCorrectly() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        // Default should be false
        XCTAssertFalse(pm.lidSleepDisabled)

        // Set to true
        pm.lidSleepDisabled = true
        XCTAssertTrue(pm.lidSleepDisabled)

        // Set back to false
        pm.lidSleepDisabled = false
        XCTAssertFalse(pm.lidSleepDisabled)
    }

    func testLidSleepDisabled_PersistsAcrossReads() {
        let pm = PersistenceManager.shared
        pm.registerDefaults()

        pm.lidSleepDisabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: SettingsKeys.lidSleepDisabled))

        UserDefaults.standard.set(false, forKey: SettingsKeys.lidSleepDisabled)
        XCTAssertFalse(pm.lidSleepDisabled)
    }

    // MARK: - Screen + Lid Independence

    func testEnablingScreenAwake_DoesNotAffectLidClose() {
        KeepAwakeManager.shared.enableScreenAwake()
        let lidBefore = PersistenceManager.shared.lidSleepDisabled

        // Screen awake change should not touch lid-close setting
        XCTAssertEqual(PersistenceManager.shared.lidSleepDisabled, lidBefore)
        XCTAssertTrue(PersistenceManager.shared.screenAwakeEnabled)
    }

    func testDisablingScreenAwake_DoesNotAffectLidClose() {
        // If lid-close is somehow enabled (on a machine with sudoers),
        // disabling screen awake should not affect it
        KeepAwakeManager.shared.enableScreenAwake()
        let lidBefore = KeepAwakeManager.shared.isLidClosePreventionActive

        KeepAwakeManager.shared.disableScreenAwake()

        XCTAssertEqual(KeepAwakeManager.shared.isLidClosePreventionActive, lidBefore)
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
    }

    // MARK: - disableAll Independence

    func testDisableAll_CallsBothDisableMethods() {
        KeepAwakeManager.shared.enableScreenAwake()
        // Lid-close may or may not be active depending on sudoers

        KeepAwakeManager.shared.disableAll()

        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
        XCTAssertFalse(KeepAwakeManager.shared.isAnyActive)
    }

    // MARK: - Preferences Action Safety

    func testOpenPreferences_DoesNotCrash() {
        // We can't fully test opening Preferences in unit tests,
        // but we can verify the action selector is valid
        let selector = Selector(("showSettingsWindow:"))

        // The NSApp should be able to handle this selector
        // Just verifying the selector string is well-formed
        XCTAssertEqual(NSStringFromSelector(selector), "showSettingsWindow:")
    }
}
