import Cocoa

/// Provides context-aware menu bar icons for each keep-awake state.
final class IconProvider {
    static let shared = IconProvider()
    private init() {}

    // MARK: - Icon Names

    private enum IconName {
        static let inactive = "sun.max"
        static let screenOnly = "display"
        static let lidOnly = "moon.zzz"
        static let both = "bolt.shield"
        static let timer = "hourglass"
        static let thermal = "flame"
    }

    // MARK: - Current State

    /// The appropriate icon for the current keep-awake state.
    var currentIcon: NSImage? {
        let name = currentSymbolName
        return NSImage(
            systemSymbolName: name,
            accessibilityDescription: toolTip
        )
    }

    /// Tooltip string for the menu bar icon.
    var toolTip: String {
        let mgr = KeepAwakeManager.shared
        let timerActive = TimerManager.shared.isTimerActive

        if ThermalMonitor.shared.isInThermalDanger {
            return "Crackinate — Thermal warning: keep-awake disabled"
        }
        if timerActive, let remaining = TimerManager.shared.remainingTime {
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            let modes = activeModesDescription
            return "Crackinate — \(modes) (\(mins):\(String(format: "%02d", secs)) remaining)"
        }
        switch (mgr.isScreenAwakeActive, mgr.isLidClosePreventionActive) {
        case (true, true):  return "Crackinate — Screen awake + Lid-close prevention"
        case (true, false): return "Crackinate — Screen awake"
        case (false, true): return "Crackinate — Lid-close prevention active"
        case (false, false):return "Crackinate — Inactive"
        }
    }

    /// Menu bar icon symbol name based on current state.
    private var currentSymbolName: String {
        let mgr = KeepAwakeManager.shared
        let timerActive = TimerManager.shared.isTimerActive

        if ThermalMonitor.shared.isInThermalDanger {
            return IconName.thermal
        }
        if timerActive {
            return IconName.timer
        }
        switch (mgr.isScreenAwakeActive, mgr.isLidClosePreventionActive) {
        case (true, true):  return IconName.both
        case (true, false): return IconName.screenOnly
        case (false, true): return IconName.lidOnly
        case (false, false):return IconName.inactive
        }
    }

    /// Human-readable description of active modes for tooltips.
    private var activeModesDescription: String {
        let mgr = KeepAwakeManager.shared
        switch (mgr.isScreenAwakeActive, mgr.isLidClosePreventionActive) {
        case (true, true):  return "Full keep-awake"
        case (true, false): return "Screen awake"
        case (false, true): return "Lid-close prevented"
        case (false, false):return "Inactive"
        }
    }
}
