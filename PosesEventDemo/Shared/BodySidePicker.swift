import SwiftUI

/// Both / Left / Right. With one side chosen, explains whose left it is.
struct BodySidePicker: View {
    @Binding var side: BodySide

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Body side", selection: $side) {
                ForEach(BodySide.allCases) { side in
                    Text(side.rawValue).tag(side)
                }
            }
            .pickerStyle(.segmented)

            if side != .both {
                Text("The person's own \(side.rawValue.lowercased()) side, not the side of the photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
