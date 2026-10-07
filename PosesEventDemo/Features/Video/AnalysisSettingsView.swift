import SwiftUI

/// Settings of the analysis: they change how long it takes and how detailed it is.
struct AnalysisSettingsView: View {
    @Binding var configuration: AnalysisConfiguration

    let video: ImportedVideo
    let onStart: () -> Void

    private static let fpsOptions = [30, 15, 10, 5, 1]
    private static let sizeOptions: [Int?] = [640, 960, 1280, nil]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Processing FPS").font(.subheadline.bold())

                Picker("Processing FPS", selection: framesPerSecond) {
                    ForEach(availableFPS, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
                .pickerStyle(.segmented)

                Text("Video: \(Int(video.nominalFrameRate.rounded())) FPS · Processing: \(Int(configuration.framesPerSecond)) FPS. More frames give a smoother skeleton but take longer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Frame size").font(.subheadline.bold())

                Picker("Frame size", selection: $configuration.maximumPixelDimension) {
                    ForEach(Self.sizeOptions, id: \.self) { size in
                        Text(size.map { "\($0) px" } ?? "Original").tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Text("Larger frames can show more detail, but need more time and memory.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: onStart) {
                Label("Start analysis", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .card()
    }

    /// Sampling cannot be faster than the video itself.
    private var availableFPS: [Int] {
        let source = Int(video.nominalFrameRate.rounded(.up))
        let options = Self.fpsOptions.filter { source <= 0 || $0 <= source }
        return options.isEmpty ? [1] : options
    }

    private var framesPerSecond: Binding<Int> {
        Binding(get: { Int(configuration.framesPerSecond) },
                set: { configuration.framesPerSecond = Double($0) })
    }
}
