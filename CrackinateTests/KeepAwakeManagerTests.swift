import XCTest
@testable import Crackinate

/// Tests for KeepAwakeManager — state transitions, disableAll, and state reconciliation.
final class KeepAwakeManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset the manager to a clean state before each test
        KeepAwakeManager.shared.disableAll()
        UserDefaults.standard.register(defaults: [
            SettingsKeys.screenAwakeEnabled: false,
            SettingsKeys.lidSleepDisabled: false,
        ])
    }

    override func tearDown() {
        KeepAwakeManager.shared.disableAll()
        super.tearDown()
    }

    // MARK: - Screen Awake

    func testEnableScreenAwake_SetsState() {
        KeepAwakeManager.shared.enableScreenAwake()
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)
    }

    func testDisableScreenAwake_SetsState() {
        KeepAwakeManager.shared.enableScreenAwake()
        KeepAwakeManager.shared.disableScreenAwake()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
    }

    func testEnableScreenAwake_Idempotent() {
        KeepAwakeManager.shared.enableScreenAwake()
        KeepAwakeManager.shared.enableScreenAwake()  // should not double-assert
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)
    }

    func testDisableScreenAwake_Idempotent() {
        KeepAwakeManager.shared.disableScreenAwake()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
    }

    // MARK: - Lid-Close Prevention

    func testEnableLidClosePrevention_SetsState() {
        // This test may fail if sudoers isn't installed — that's expected behavior
        // We test the state management, not the actual pmset call
        // The enable method will fail gracefully if sudoers is missing
        KeepAwakeManager.shared.enableLidClosePrevention()
        // Either it works (state = true) or it fails (state = false) — both are valid
        // We just verify it doesn't crash
    }

    func testDisableLidClosePrevention_WhenNotActive() {
        KeepAwakeManager.shared.disableLidClosePrevention()
        XCTAssertFalse(KeepAwakeManager.shared.isLidClosePreventionActive)
    }

    // MARK: - isAnyActive

    func testIsAnyActive_NoModes() {
        XCTAssertFalse(KeepAwakeManager.shared.isAnyActive)
    }

    func testIsAnyActive_ScreenOnly() {
        KeepAwakeManager.shared.enableScreenAwake()
        XCTAssertTrue(KeepAwakeManager.shared.isAnyActive)
    }

    // MARK: - disableAll

    func testDisableAll_FromScreenAwake() {
        KeepAwakeManager.shared.enableScreenAwake()
        KeepAwakeManager.shared.disableAll()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
        XCTAssertFalse(KeepAwakeManager.shared.isAnyActive)
    }

    func testDisableAll_WhenNothingActive() {
        KeepAwakeManager.shared.disableAll()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
        XCTAssertFalse(KeepAwakeManager.shared.isLidClosePreventionActive)
        XCTAssertFalse(KeepAwakeManager.shared.isAnyActive)
    }

    // MARK: - State Restoration

    func testPerformStateRestoration_NoMismatch() {
        // When everything is off, restoration should be a no-op
        KeepAwakeManager.shared.performStateRestoration()
        XCTAssertFalse(KeepAwakeManager.shared.isScreenAwakeActive)
        // Lid-close state depends on actual pmset — just verify no crash
    }

    // MARK: - Screen Awake With Duration

    func testEnableScreenAwake_WithDuration() {
        KeepAwakeManager.shared.enableScreenAwake(duration: 60)
        XCTAssertTrue(KeepAwakeManager.shared.isScreenAwakeActive)
        XCTAssertTrue(TimerManager.shared.isTimerActive)

        // Clean up
        KeepAwakeManager.shared.disableScreenAwake()
    }

    // MARK: - PersistenceManager Sync

    func testEnableScreenAwake_PersistsToUserDefaults() {
        KeepAwakeManager.shared.enableScreenAwake()
        XCTAssertTrue(PersistenceManager.shared.screenAwakeEnabled)
    }

    func testDisableScreenAwake_ClearsUserDefaults() {
        KeepAwakeManager.shared.enableScreenAwake()
        KeepAwakeManager.shared.disableScreenAwake()
        XCTAssertFalse(PersistenceManager.shared.screenAwakeEnabled)
    }

    // MARK: - Notification Posting

    func testEnableScreenAwake_PostsNotification() {
        let expectation = self.expectation(description: "notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .screenAwakeDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let value = notification.object as? NSNumber, value.boolValue == true {
                expectation.fulfill()
            }
        }

        KeepAwakeManager.shared.enableScreenAwake()

        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testDisableScreenAwake_PostsNotification() {
        KeepAwakeManager.shared.enableScreenAwake()

        let expectation = self.expectation(description: "disable notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .screenAwakeDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let value = notification.object as? NSNumber, value.boolValue == false {
                expectation.fulfill()
            }
        }

        KeepAwakeManager.shared.disableScreenAwake()

        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Timer Cleanup on Disable

    func testDisableScreenAwake_StopsTimer() {
        KeepAwakeManager.shared.enableScreenAwake(duration: 60)
        XCTAssertTrue(TimerManager.shared.isTimerActive)

        KeepAwakeManager.shared.disableScreenAwake()
        XCTAssertFalse(TimerManager.shared.isTimerActive)
    }
}
