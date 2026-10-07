import AVFoundation
import SwiftUI

/// The video of one engine: player + boxes of people + the pose of this engine.
struct VideoAnalysisSurface: View {
    let player: AVPlayer
    let videoSize: CGSize
    let analysis: FrameAnalysis?
    let engine: PoseEngine
    let settings: VideoOverlaySettings
    let isAnalyzing: Bool

    var body: some View {
        ZStack {
            Color.black

            PlayerLayerView(player: player)

            if settings.showsBoxes {
                PersonBoxOverlayView(people: analysis?.people ?? [],
                                     imageSize: videoSize,
                                     minConfidence: settings.minConfidence)
            }

            // Colors come from people matched across both engines, so the same person
            // has the same color in the ML Kit and in the Vision video.
            PoseOverlayView(poses: analysis?.poses[engine]?.poses ?? [],
                            imageSize: videoSize,
                            showsSkeleton: settings.showsSkeleton,
                            showsLandmarks: settings.showsLandmarks,
                            minConfidence: settings.minConfidence,
                            personColors: PersonMatcher.colorIndices(for: engine,
                                                                     in: PersonMatcher.match(analysis?.poses ?? [:])),
                            side: settings.side)

            if isAnalyzing {
                VStack {
                    HStack {
                        Label("Live", systemImage: "waveform.path.ecg")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.65), in: .capsule)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(engine.rawValue) video")
    }

    /// Very tall or very wide videos are limited, so the two panels stay a sensible size.
    private var aspectRatio: CGFloat {
        guard videoSize.width > 0, videoSize.height > 0 else { return 16 / 9 }
        return min(max(videoSize.width / videoSize.height, 3 / 4), 16 / 9)
    }
}
