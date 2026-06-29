import SwiftUI

/// Displays a live countdown timer with remaining time and a stop button.
struct CountdownDisplay: View {
    let remainingTime: TimeInterval
    let onStop: () -> Void

    private var timeString: String {
        let total = Int(max(0, remainingTime))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .foregroundStyle(.orange)

            Text("⏳ \(timeString) remaining")
                .font(.callout)
                .monospacedDigit()

            Spacer()

            Button("Stop", action: onStop)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
