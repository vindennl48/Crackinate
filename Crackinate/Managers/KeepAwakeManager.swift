import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when screen-awake state changes. Object is `true`/`false` as NSNumber.
    static let screenAwakeDidChange = Notification.Name("CrackinateScreenAwakeDidChange")
    /// Posted when lid-close prevention state changes. Object is `true`/`false` as NSNumber.
    static let lidClosePreventionDidChange = Notification.Name("CrackinateLidClosePreventionDidChange")
}

// MARK: - Pmset Error

enum PmsetError: Error, LocalizedError {
    case requiresSudoers
    case commandFailed(String)
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .requiresSudoers:
            return "Root privileges required. Run the one-time setup to enable lid-close sleep prevention."
        case .commandFailed(let detail):
            return "pmset command failed: \(detail)"
        case .notInstalled:
            return "pmset is not available on this system."
        }
    }
}

// MARK: - Pmset Controller

/// Low-level wrapper around `/usr/bin/pmset` for lid-close sleep management.
enum PmsetController {
    private static let pmsetPath = "/usr/bin/pmset"
    private static let sudoPath = "/usr/bin/sudo"

    /// Check whether `disablesleep` is currently enabled (1).
    static func isSleepDisabled() -> Bool {
        // Quick check via pmset -g (no sudo needed to read)
        guard let output = run(pmsetPath, arguments: ["-g", "live"]) else { return false }
        return parseSleepDisabled(from: output)
    }

    /// Set `disablesleep` to 1 (prevent sleep) or 0 (allow sleep).
    /// Requires the sudoers file to be installed for passwordless operation.
    static func setDisableSleep(_ disable: Bool) throws {
        let value = disable ? "1" : "0"

        // Use sudo so it doesn't prompt if the sudoers file is installed
        let result = run(sudoPath, arguments: [pmsetPath, "-a", "disablesleep", value])

        if result == nil {
            throw PmsetError.commandFailed("Unable to execute pmset")
        }

        // Verify the change took effect
        Thread.sleep(forTimeInterval: 0.3)
        let current = isSleepDisabled()
        if current != disable {
            // pmset may have failed due to missing sudoers — try to detect the reason
            if !SudoersInstaller.shared.isInstalled() {
                throw PmsetError.requiresSudoers
            }
            throw PmsetError.commandFailed("pmset ran but state did not change to \(value)")
        }
    }

    // MARK: - Private Helpers

    private static func run(_ executable: String, arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("[Crackinate] pmset process error: \(error)")
            return nil
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outData, encoding: .utf8)
    }

    /// Parse "SleepDisabled  1" or "SleepDisabled  0" from `pmset -g live` output.
    static func parseSleepDisabled(from output: String) -> Bool {
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SleepDisabled") {
                // Format: "SleepDisabled            1"
                let parts = trimmed.components(separatedBy: .whitespaces)
                if let last = parts.last, last == "1" {
                    return true
                }
                return false
            }
        }
        return false
    }
}

// MARK: - Keep-Awake Manager

/// Central singleton managing screen-sleep assertions and lid-close sleep prevention.
final class KeepAwakeManager {
    static let shared = KeepAwakeManager()
    private init() {
        // Defer state restoration to after app launch
    }

    // MARK: - Screen Sleep

    /// The retained activity token from NSProcessInfo.beginActivity.
    private var screenActivity: NSObjectProtocol?

    /// Whether screen sleep is currently being prevented.
    private(set) var isScreenAwakeActive: Bool = false

    /// Prevent the display and system from idle-sleeping.
    func enableScreenAwake(duration: TimeInterval? = nil) {
        guard screenActivity == nil else { return }

        let options: ProcessInfo.ActivityOptions = [
            .idleSystemSleepDisabled,
            .idleDisplaySleepDisabled,
        ]
        screenActivity = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Crackinate: User requested keep-awake mode"
        )

        isScreenAwakeActive = true
        PersistenceManager.shared.screenAwakeEnabled = true
        postScreenAwakeNotification()

        // If a duration was specified, schedule auto-disable
        if let duration = duration {
            TimerManager.shared.startTimer(duration: duration) { [weak self] in
                self?.disableScreenAwake()
            }
        }

        print("[Crackinate] Screen awake enabled")
    }

    /// Release the screen-sleep assertion.
    func disableScreenAwake() {
        guard let activity = screenActivity else { return }

        ProcessInfo.processInfo.endActivity(activity)
        screenActivity = nil

        isScreenAwakeActive = false
        PersistenceManager.shared.screenAwakeEnabled = false
        TimerManager.shared.stopTimer()
        postScreenAwakeNotification()

        print("[Crackinate] Screen awake disabled")
    }

    // MARK: - Lid-Close Prevention

    /// Whether lid-close sleep is currently being prevented (pmset disablesleep 1).
    private(set) var isLidClosePreventionActive: Bool = false

    /// Prevent the Mac from sleeping when the lid is closed.
    func enableLidClosePrevention(duration: TimeInterval? = nil) {
        guard !isLidClosePreventionActive else { return }

        do {
            try PmsetController.setDisableSleep(true)
            isLidClosePreventionActive = true
            PersistenceManager.shared.lidSleepDisabled = true
            postLidCloseNotification()

            // If a duration was specified, schedule auto-disable
            if let duration = duration {
                TimerManager.shared.startTimer(duration: duration) { [weak self] in
                    self?.disableLidClosePrevention()
                }
            }

            print("[Crackinate] Lid-close prevention enabled")
        } catch {
            print("[Crackinate] Failed to enable lid-close prevention: \(error.localizedDescription)")
            // Re-throw? No — post a notification so the UI can show an alert
            NotificationCenter.default.post(
                name: .lidClosePreventionDidChange,
                object: false
            )
        }
    }

    /// Re-enable normal lid-close sleep behavior.
    func disableLidClosePrevention() {
        guard isLidClosePreventionActive else { return }

        do {
            try PmsetController.setDisableSleep(false)
        } catch {
            print("[Crackinate] Warning: Failed to disable lid-close prevention: \(error.localizedDescription)")
            // Even if pmset fails, update our local state to avoid stale state
        }

        isLidClosePreventionActive = false
        PersistenceManager.shared.lidSleepDisabled = false
        TimerManager.shared.stopTimer()
        postLidCloseNotification()

        print("[Crackinate] Lid-close prevention disabled")
    }

    // MARK: - Both

    /// Whether any keep-awake mode is active.
    var isAnyActive: Bool { isScreenAwakeActive || isLidClosePreventionActive }

    /// Release all assertions and re-enable sleep. Called on app quit and thermal critical.
    func disableAll() {
        disableScreenAwake()
        disableLidClosePrevention()
        print("[Crackinate] All keep-awake modes disabled")
    }

    // MARK: - State Restoration

    /// Check pmset state on launch and reconcile with persisted settings.
    /// If `pmset disablesleep` is 1 but our settings say false, the app or system
    /// crashed while prevention was active — offer to correct it.
    func performStateRestoration() {
        let pmsetDisabled = PmsetController.isSleepDisabled()
        let settingsDisabled = PersistenceManager.shared.lidSleepDisabled

        if pmsetDisabled && !settingsDisabled {
            print("[Crackinate] State mismatch: pmset shows disabled but settings say enabled=false")
            // Post notification so UI can show an alert offering to fix
            NotificationCenter.default.post(
                name: .lidClosePreventionDidChange,
                object: true // true = mismatch detected
            )
        } else if settingsDisabled {
            // Settings say lid-close prevention was enabled. Re-enable it.
            // This handles the case where the system was rebooted — pmset disablesleep
            // persists, so we just need to update our local state.
            if pmsetDisabled {
                isLidClosePreventionActive = true
                postLidCloseNotification()
                print("[Crackinate] Restored lid-close prevention state from pmset")
            } else {
                // Settings say enabled, but pmset says disabled — something reset it.
                // Clear the setting to match reality.
                PersistenceManager.shared.lidSleepDisabled = false
                print("[Crackinate] State mismatch: settings said enabled but pmset shows disabled. Corrected.")
            }
        }

        // Screen awake assertions never persist across launches, so always start disabled.
    }

    // MARK: - Private

    private func postScreenAwakeNotification() {
        NotificationCenter.default.post(
            name: .screenAwakeDidChange,
            object: NSNumber(value: isScreenAwakeActive)
        )
        NotificationCenter.default.post(
            name: .lidClosePreventionDidChange,
            object: NSNumber(value: isLidClosePreventionActive)
        )
    }

    private func postLidCloseNotification() {
        NotificationCenter.default.post(
            name: .lidClosePreventionDidChange,
            object: NSNumber(value: isLidClosePreventionActive)
        )
    }
}
