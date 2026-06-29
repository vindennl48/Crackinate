import SwiftUI

/// Predefined timer duration options.
enum TimerDuration: Int, CaseIterable, Identifiable {
    case forever = 0
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .forever:        return "Forever"
        case .fiveMinutes:    return "5 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes:  return "30 min"
        case .oneHour:        return "1 hr"
        case .twoHours:       return "2 hr"
        }
    }
}

/// Segmented picker for choosing keep-awake duration.
struct TimerPicker: View {
    @Binding var selectedDuration: TimerDuration

    var body: some View {
        HStack(spacing: 4) {
            Text("Timer:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Timer", selection: $selectedDuration) {
                ForEach(TimerDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
        }
    }
}
