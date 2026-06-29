import XCTest
@testable import Crackinate

/// Tests for low-level pmset output parsing and the PmsetController logic.
final class PmsetControllerTests: XCTestCase {

    // MARK: - parseSleepDisabled Tests

    func testParseSleepDisabled_Enabled() {
        let output = "SleepDisabled\t\t1"
        XCTAssertTrue(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_Disabled() {
        let output = "SleepDisabled\t\t0"
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_NotPresent() {
        let output = "SomeOtherSetting    1"
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_Empty() {
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: ""))
    }

    func testParseSleepDisabled_ExtraWhitespace() {
        let output = "    SleepDisabled            1    "
        XCTAssertTrue(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_TrailingText_NotValid() {
        // Real pmset output has no trailing text on setting lines.
        // The parser only matches lines that START with "SleepDisabled".
        let output = "SleepDisabled\t\t1 (enabled by Crackinate)"
        // The function checks hasPrefix("SleepDisabled") — this passes.
        // But the last token is "Crackinate)" not "1" — so result is false.
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_MalformedLine() {
        let output = "SleepDisabled\t\tnotanumber"
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_MultipleLines_FirstMatchWins() {
        let output = "SleepDisabled\t\t1\nSleepDisabled\t\t0"
        XCTAssertTrue(PmsetController.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabled_LineWithExtraPrefix_NoMatch() {
        // Lines not starting with "SleepDisabled" should not match,
        // even if SleepDisabled appears later in the line.
        let output = "SomePrefix SleepDisabled\t\t1 extra"
        XCTAssertFalse(PmsetController.parseSleepDisabled(from: output))
    }

    // MARK: - PmsetError Tests

    func testPmsetError_RequiresSudoers_HasDescription() {
        let desc = PmsetError.requiresSudoers.errorDescription ?? ""
        XCTAssertFalse(desc.isEmpty)
    }

    func testPmsetError_NotInstalled_HasDescription() {
        let desc = PmsetError.notInstalled.errorDescription ?? ""
        XCTAssertFalse(desc.isEmpty)
    }

    func testPmsetError_CommandFailed_IncludesMessage() {
        let error = PmsetError.commandFailed("specific error details")
        XCTAssertTrue(error.errorDescription?.contains("specific error details") ?? false)
    }
}
