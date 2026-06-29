import Foundation
import IOKit

/// Detects whether the MacBook lid is open or closed via IORegistry.
/// On desktop Macs (iMac, Mac Studio), the AppleClamshellState service doesn't
/// exist and isLidClosed returns false.
final class LidDetector {
    static let shared = LidDetector()
    private init() {}

    /// Whether the lid is currently closed.
    private(set) var isLidClosed: Bool = false

    private var pollTimer: Timer?

    /// Start polling the IORegistry for lid state changes.
    func startPolling(interval: TimeInterval = 2.0) {
        // Get initial state
        isLidClosed = Self.checkLidClosed()

        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let closed = Self.checkLidClosed()
            if closed != self.isLidClosed {
                self.isLidClosed = closed
                NotificationCenter.default.post(
                    name: .lidStateDidChange,
                    object: NSNumber(value: closed)
                )
            }
        }

        print("[Crackinate] Lid detection started — closed: \(isLidClosed)")
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Static Check

    static func checkLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleClamshellState")
        )
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let result = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else { return false }

        defer { result.release() }

        let value = result.takeRetainedValue()

        // Newer macOS: value is a direct CFBoolean (true/false)
        if let closed = value as? Bool {
            return closed
        }

        // Older macOS: value is a dictionary with "ClamshellState" key
        if let dict = value as? [String: Any],
           let closed = dict["ClamshellState"] as? Bool {
            return closed
        }

        return false
    }
}

// MARK: - Notification

extension Notification.Name {
    static let lidStateDidChange = Notification.Name("CrackinateLidStateDidChange")
}
