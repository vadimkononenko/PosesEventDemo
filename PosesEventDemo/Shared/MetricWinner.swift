import SwiftUI

enum MetricGoal {
    case higher
    case lower
}

enum MetricWinner {
    /// The engine with the best value. `nil` when not every engine has a value or the best
    /// values are equal: then there is nothing to highlight.
    ///
    /// Pass the value as it is shown (rounded), so "41 ms" vs "41 ms" is not a win.
    static func winner(_ values: [PoseEngine: Double], goal: MetricGoal) -> PoseEngine? {
        guard values.count == PoseEngine.allCases.count, values.count >= 2 else { return nil }

        let sorted = values.sorted { goal == .higher ? $0.value > $1.value : $0.value < $1.value }
        guard abs(sorted[0].value - sorted[1].value) > 1e-9 else { return nil }
        return sorted[0].key
    }
}

/// A value in a comparison table. The winner gets a green capsule.
struct MetricValue: View {
    let text: String
    var isWinner = false

    var body: some View {
        Text(text)
            .font(.footnote.monospacedDigit().weight(isWinner ? .bold : .regular))
            .foregroundStyle(isWinner ? Color.green : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                if isWinner {
                    Capsule().fill(Color.green.opacity(0.15))
                }
            }
            .accessibilityLabel(isWinner ? "\(text), best" : text)
    }
}
