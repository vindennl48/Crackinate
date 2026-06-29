import Foundation

/// Manages the one-time installation of a passwordless sudoers file for pmset.
/// Full implementation in Phase P6.
final class SudoersInstaller {
    static let shared = SudoersInstaller()
    private init() {}

    /// Check if the sudoers file exists.
    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/etc/sudoers.d/crackinate")
    }

    /// Install the sudoers file (requires admin privileges).
    /// Uses AppleScript `do shell script ... with administrator privileges`.
    func install() throws {
        let sudoersContent = """
        # Crackinate — passwordless pmset for lid-close sleep toggle
        ALL ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1

        """

        // Write to a temp file
        let tempPath = NSTemporaryDirectory() + "crackinate_sudoers"
        try sudoersContent.write(toFile: tempPath, atomically: true, encoding: .utf8)

        // Use AppleScript to move with admin privileges
        let script = """
        do shell script "cp \(tempPath) /etc/sudoers.d/crackinate && chmod 440 /etc/sudoers.d/crackinate && rm \(tempPath)" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            throw NSError(
                domain: "SudoersInstall",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(error)"]
            )
        }

        print("[Crackinate] Sudoers file installed successfully")
    }

    /// Remove the sudoers file (requires admin privileges).
    func uninstall() throws {
        let script = """
        do shell script "rm -f /etc/sudoers.d/crackinate" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            throw NSError(
                domain: "SudoersInstall",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "\(error)"]
            )
        }

        print("[Crackinate] Sudoers file removed")
    }
}
