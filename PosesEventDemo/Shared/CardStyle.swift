import SwiftUI

extension View {
    /// A soft rounded card for a group of controls or numbers.
    func card() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

enum VideoTimeFormatter {
    /// `1:05.3`
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00.0" }
        let total = max(seconds, 0)
        let minutes = Int(total) / 60
        return String(format: "%d:%04.1f", minutes, total - Double(minutes * 60))
    }
}
