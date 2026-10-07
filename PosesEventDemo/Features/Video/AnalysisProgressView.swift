import SwiftUI

struct AnalysisProgressView: View {
    let progress: Double
    let analyzedFrameCount: Int
    let currentTime: Double?
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Analyzing", systemImage: "waveform.path.ecg")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int((progress * 100).rounded())) %")
                    .font(.subheadline.monospacedDigit().bold())
            }

            ProgressView(value: progress)

            HStack {
                Text(status)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .card()
    }

    private var status: String {
        let frames = "\(analyzedFrameCount) \(analyzedFrameCount == 1 ? "frame" : "frames")"
        guard let currentTime else { return frames }
        return "\(frames) · \(VideoTimeFormatter.string(from: currentTime))"
    }
}
