import XCTest
@testable import Crackinate

/// Tests for TimerManager — countdown creation, cancellation, expiry callback.
final class TimerManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure timer is stopped before each test
        TimerManager.shared.stopTimer()
    }

    override func tearDown() {
        TimerManager.shared.stopTimer()
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_IsNotActive() {
        XCTAssertFalse(TimerManager.shared.isTimerActive)
        XCTAssertNil(TimerManager.shared.remainingTime)
    }

    // MARK: - Start / Stop

    func testStartTimer_SetsRemainingTime() {
        let expectation = self.expectation(description: "timer starts")

        TimerManager.shared.startTimer(duration: 5.0) {
            // expiry callback — won't fire in this test
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(TimerManager.shared.isTimerActive)
            XCTAssertNotNil(TimerManager.shared.remainingTime)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testStopTimer_ClearsState() {
        let expectation = self.expectation(description: "timer stops")

        TimerManager.shared.startTimer(duration: 10.0) {
            XCTFail("Expiry callback should not fire after stop")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(TimerManager.shared.isTimerActive)
            TimerManager.shared.stopTimer()

            XCTAssertFalse(TimerManager.shared.isTimerActive)
            XCTAssertNil(TimerManager.shared.remainingTime)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testStartTimer_StopsPreviousTimer() {
        _ = {
            // Callbacks for first and second timers — both should be cancelled
        }

        TimerManager.shared.startTimer(duration: 10.0) {}
        TimerManager.shared.startTimer(duration: 10.0) {}

        // Only the second timer should be active
        XCTAssertTrue(TimerManager.shared.isTimerActive)
        TimerManager.shared.stopTimer()
        XCTAssertFalse(TimerManager.shared.isTimerActive)
    }

    // MARK: - Expiry

    func testTimerExpiry_FiresCallback() {
        let expectation = self.expectation(description: "timer expires")

        TimerManager.shared.startTimer(duration: 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testTimerExpiry_ClearsState() {
        let expectation = self.expectation(description: "timer expires and clears state")

        TimerManager.shared.startTimer(duration: 0.5) {
            XCTAssertFalse(TimerManager.shared.isTimerActive)
            XCTAssertNil(TimerManager.shared.remainingTime)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Countdown Decrements

    func testCountdown_DecrementsOverTime() {
        let expectation = self.expectation(description: "countdown decrements")

        TimerManager.shared.startTimer(duration: 10.0) {}

        // After 1 second, the remaining time should be roughly 9 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let remaining = TimerManager.shared.remainingTime ?? 0
            XCTAssertGreaterThan(remaining, 0)
            XCTAssertLessThanOrEqual(remaining, 9.5)  // should be ~9.0, allow some slop
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Negative Duration

    func testStartTimer_NegativeDuration_ExpiresImmediately() {
        let expectation = self.expectation(description: "negative duration expires")

        TimerManager.shared.startTimer(duration: -1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Zero Duration

    func testStartTimer_ZeroDuration_ExpiresImmediately() {
        let expectation = self.expectation(description: "zero duration expires")

        TimerManager.shared.startTimer(duration: 0.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
