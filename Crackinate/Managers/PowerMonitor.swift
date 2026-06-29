import Foundation
import IOKit.ps

/// Monitors AC vs battery power state.
final class PowerMonitor {
    static let shared = PowerMonitor()
    private init() {}

    /// Whether the Mac is currently on AC power.
    private(set) var isOnACPower: Bool = true

    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?

    func startMonitoring(pollInterval: TimeInterval = 10.0) {
        // Get initial state
        isOnACPower = Self.checkACPower()

        // Poll as a fallback (IOPS notifications can be unreliable)
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            let wasAC = self?.isOnACPower ?? true
            self?.isOnACPower = Self.checkACPower()
            if wasAC != self?.isOnACPower {
                // State changed
                NotificationCenter.default.post(
                    name: .powerSourceDidChange,
                    object: self?.isOnACPower
                )
            }
        }

        // Also register for IOPS notifications for faster response
        let context = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let ctx = context else { return }
                let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
                let wasAC = monitor.isOnACPower
                monitor.isOnACPower = PowerMonitor.checkACPower()
                if wasAC != monitor.isOnACPower {
                    NotificationCenter.default.post(
                        name: .powerSourceDidChange,
                        object: monitor.isOnACPower
                    )
                }
            },
            context
        )?.takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        print("[Crackinate] Power monitoring started — AC: \(isOnACPower)")
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }

    // MARK: - Static Check

    static func checkACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return true // Assume AC if can't determine
        }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] else {
            return true
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?
                .takeUnretainedValue() as? [String: Any] else { continue }

            if let powerSource = info[kIOPSPowerSourceStateKey] as? String {
                return powerSource == kIOPSACPowerValue
            }
        }
        return true
    }
}

// MARK: - Notification

extension Notification.Name {
    static let powerSourceDidChange = Notification.Name("CrackinatePowerSourceDidChange")
}
