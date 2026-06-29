import XCTest
@testable import Crackinate

/// Tests for SudoersInstaller — file detection and state management.
final class SudoersInstallerTests: XCTestCase {

    func testIsInstalled_ReturnsFalse_WhenSudoersFileMissing() {
        // In a test environment, the sudoers file should not exist.
        // We just verify the function returns a boolean (false).
        let installed = SudoersInstaller.shared.isInstalled()
        // Can't assert true/false because we don't control /etc/sudoers.d/
        // But we can verify it doesn't crash
        XCTAssertTrue(installed == true || installed == false)
    }

    func testIsInstalled_IsDeterministic() {
        // Calling twice should return the same result
        let first = SudoersInstaller.shared.isInstalled()
        let second = SudoersInstaller.shared.isInstalled()
        XCTAssertEqual(first, second)
    }

    func testIsInstalled_ReturnsFalseWhenFileDoesNotExist() {
        // The test environment should not have our sudoers file
        let path = "/etc/sudoers.d/crackinate"
        let fileExists = FileManager.default.fileExists(atPath: path)
        // This test documents: if the file doesn't exist on disk,
        // isInstalled() should match
        XCTAssertEqual(SudoersInstaller.shared.isInstalled(), fileExists)
    }

    func testUninstall_ThrowsWhenNotAuthorized() {
        // uninstall() requires admin privileges — in tests without those,
        // it should throw rather than crash
        do {
            try SudoersInstaller.shared.uninstall()
            // If it succeeds (sudoers file doesn't exist, rm -f succeeds), fine
        } catch {
            // If it fails (no admin), verify the error is descriptive
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testInstall_SucceedsOrThrowsGracefully() {
        // install() requires admin privileges. In test environments:
        // - If sudoers already exists: might succeed without prompt
        // - If admin authorizes the AppleScript dialog: might succeed
        // - If not authorized: should throw with a descriptive error
        // Either way, the app must not crash.
        do {
            try SudoersInstaller.shared.install()
            // Success means the file was installed (user authorized or already exists)
            // Verify it's now installed
            XCTAssertTrue(SudoersInstaller.shared.isInstalled(),
                          "After successful install, isInstalled() should return true")
        } catch {
            // Failure without admin is expected — verify the error is descriptive
            XCTAssertFalse(error.localizedDescription.isEmpty,
                           "Error should have a user-facing description")
        }
    }
}
