import Foundation

/// Monitors system thermal state and auto-disables keep-awake on critical.
final class ThermalMonitor {
    static let shared = ThermalMonitor()
    private init() {}

    /// Whether the system is currently in thermal danger (serious or critical).
    var isInThermalDanger: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func thermalStateDidChange(_ notification: Notification) {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .critical:
            if PersistenceManager.shared.autoDisableOnThermal {
                KeepAwakeManager.shared.disableAll()
                NotificationManager.shared.send(
                    title: "Critical Temperature",
                    body: "Crackinate disabled keep-awake to protect your Mac."
                )
            }
        case .serious:
            NotificationManager.shared.send(
                title: "High Temperature",
                body: "Your Mac is getting hot. Consider disabling keep-awake."
            )
        case .nominal, .fair:
            break
        @unknown default:
            break
        }
    }
}
