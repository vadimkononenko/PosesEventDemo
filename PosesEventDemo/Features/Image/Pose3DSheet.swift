import SwiftUI

/// The photo's person as a 3D skeleton (Vision `DetectHumanBodyPose3DRequest`).
struct Pose3DSheet: View {
    let image: UIImage

    @State private var viewModel = Pose3DViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                content
            }
            .padding()
            .navigationTitle("3D pose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await viewModel.detect(in: image) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Estimating 3D pose…")
                .frame(maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("3D pose failed", systemImage: "cube.transparent")
            } description: {
                Text(message)
            }

        case .done(let result):
            if let person = result.people.first {
                Pose3DSceneView(result: result)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(person.joints.count) joints, in meters · \(Int(result.duration * 1000)) ms")
                    Text(String(format: "Body height %.2f m (%@)",
                                person.bodyHeightMeters,
                                person.isHeightMeasured ? "measured" : "estimated"))
                    if result.people.count > 1 {
                        Text("Showing person 1 of \(result.people.count)")
                    }
                    Text("Drag to rotate, pinch to zoom. Blue: left side, orange: right side.")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
                .card()
            } else {
                ContentUnavailableView("No person found",
                                       systemImage: "figure.stand",
                                       description: Text("The 3D request needs a whole person in the photo."))
            }
        }
    }
}
