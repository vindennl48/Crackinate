import Foundation

/// Manages countdown timers for keep-awake duration limits.
/// Full implementation in Phase P3.
final class TimerManager {
    static let shared = TimerManager()
    private init() {}

    /// Published remaining time in seconds. nil when no timer is active.
    private(set) var remainingTime: TimeInterval?

    /// Whether a timer is currently active.
    var isTimerActive: Bool { remainingTime != nil }

    // Internal state
    private var expiryWorkItem: DispatchWorkItem?
    private var countdownTimer: Timer?
    private var startTime: Date?
    private var totalDuration: TimeInterval = 0

    /// Start a countdown timer. When it expires, calls `onExpiry`.
    func startTimer(duration: TimeInterval, onExpiry: @escaping () -> Void) {
        stopTimer()

        totalDuration = duration
        startTime = Date()
        remainingTime = duration

        // Schedule the expiry callback
        let workItem = DispatchWorkItem { [weak self] in
            self?.remainingTime = nil
            self?.countdownTimer?.invalidate()
            self?.countdownTimer = nil
            self?.startTime = nil
            self?.totalDuration = 0
            PersistenceManager.shared.isTimerActive = false
            onExpiry()
        }
        expiryWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + duration,
            execute: workItem
        )

        // Update the countdown display every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            self.remainingTime = max(0, self.totalDuration - elapsed)
        }

        PersistenceManager.shared.isTimerActive = true
        print("[Crackinate] Timer started: \(Int(duration))s")
    }

    /// Cancel the timer without calling the expiry callback.
    func stopTimer() {
        expiryWorkItem?.cancel()
        expiryWorkItem = nil

        countdownTimer?.invalidate()
        countdownTimer = nil

        remainingTime = nil
        startTime = nil
        totalDuration = 0

        PersistenceManager.shared.isTimerActive = false
        print("[Crackinate] Timer stopped")
    }
}
