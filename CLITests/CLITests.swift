import XCTest
@testable import CrackinateCLI

final class CLIParseDurationTests: XCTestCase {

    func test5Minutes() {
        XCTAssertEqual(parseDuration("5m"), 300)
        XCTAssertEqual(parseDuration("5min"), 300)
    }

    func test15Minutes() {
        XCTAssertEqual(parseDuration("15m"), 900)
        XCTAssertEqual(parseDuration("15min"), 900)
    }

    func test30Minutes() {
        XCTAssertEqual(parseDuration("30m"), 1800)
        XCTAssertEqual(parseDuration("30min"), 1800)
    }

    func test1Hour() {
        XCTAssertEqual(parseDuration("1h"), 3600)
        XCTAssertEqual(parseDuration("1hr"), 3600)
    }

    func test2Hours() {
        XCTAssertEqual(parseDuration("2h"), 7200)
        XCTAssertEqual(parseDuration("2hr"), 7200)
    }

    func testForever() {
        XCTAssertEqual(parseDuration("forever"), 0)
    }

    func testInvalidDuration() {
        XCTAssertNil(parseDuration("10m"))
        XCTAssertNil(parseDuration("abc"))
        XCTAssertNil(parseDuration(""))
        XCTAssertNil(parseDuration("5mins"))
        XCTAssertNil(parseDuration("1hour"))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(parseDuration("5M"), 300)
        XCTAssertEqual(parseDuration("30Min"), 1800)
        XCTAssertEqual(parseDuration("1H"), 3600)
        XCTAssertEqual(parseDuration("Forever"), 0)
    }

    func testWhitespace() {
        XCTAssertNil(parseDuration(" 5m"))
        XCTAssertNil(parseDuration("5m "))
        XCTAssertNil(parseDuration(" 5m "))
    }
}

final class CLISetupHintsTests: XCTestCase {

    /// Capture printed output for verification.
    private func captureOutput(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let orig = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        pipe.fileHandleForWriting.closeFile()
        block()
        fflush(stdout)
        dup2(orig, STDOUT_FILENO)
        close(orig)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func testShowSetupHints_AppNotRunning() {
        let output = captureOutput {
            showSetupHints(from: "")
        }
        XCTAssertTrue(output.contains("Could not reach Crackinate app"))
        XCTAssertTrue(output.contains("is it running?"))
    }

    func testShowSetupHints_LidActive() {
        let output = captureOutput {
            showSetupHints(from: "Lid-close prevention active | Timer: 14:00 remaining")
        }
        // No hint should be printed when lid is active
        XCTAssertFalse(output.contains("⚠"))
    }

    func testShowSetupHints_LidNotActive() {
        let output = captureOutput {
            showSetupHints(from: "Screen awake")
        }
        XCTAssertTrue(output.contains("Lid-close sleep prevention not active"))
        XCTAssertTrue(output.contains("complete one-time setup"))
    }

    func testShowSetupHints_Inactive() {
        // When status is "Inactive" but not empty, it means the app responded
        // but lid is not active. Should show the setup hint.
        let output = captureOutput {
            showSetupHints(from: "Inactive")
        }
        XCTAssertTrue(output.contains("Lid-close sleep prevention not active"))
    }
}

final class CLINotificationNamesTests: XCTestCase {

    func testNotificationNamesAreUnique() {
        let names: Set<String> = [
            notificationActivate,
            notificationDeactivate,
            notificationScreenOn,
            notificationScreenOff,
            notificationLidOn,
            notificationLidOff,
            notificationStatus,
            notificationTimer,
            notificationStatusReply,
        ]
        // All 9 notifications should be unique
        XCTAssertEqual(names.count, 9)
    }

    func testNotificationNamesHaveCorrectPrefix() {
        XCTAssertTrue(notificationActivate.hasPrefix("com.crackinate."))
        XCTAssertTrue(notificationDeactivate.hasPrefix("com.crackinate."))
        XCTAssertTrue(notificationStatus.hasPrefix("com.crackinate."))
    }

    func testStatusReplyHasCorrectName() {
        XCTAssertEqual(notificationStatusReply, "com.crackinate.statusReply")
    }
}
