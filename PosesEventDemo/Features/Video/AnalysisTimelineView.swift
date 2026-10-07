import SwiftUI

/// A timeline with a tick for every analyzed frame. Drag to seek.
struct AnalysisTimelineView: View {
    let frames: [FrameAnalysis]
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    private let knob: CGFloat = 18

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)

                    Circle()
                        .fill(.tint)
                        .frame(width: knob, height: knob)
                        .shadow(radius: 1, y: 0.5)
                        .offset(x: playheadOffset(width: geometry.size.width))
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0, geometry.size.width > 0 else { return }
                            let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                            onSeek(Double(fraction) * duration)
                        }
                )
            }
            .frame(height: 32)
            .accessibilityElement()
            .accessibilityLabel("Video timeline")
            .accessibilityValue(VideoTimeFormatter.string(from: currentTime))
            .accessibilityAdjustableAction { direction in
                let step = max(duration / 100, 1)
                switch direction {
                case .increment: onSeek(min(currentTime + step, duration))
                case .decrement: onSeek(max(currentTime - step, 0))
                @unknown default: break
                }
            }

            HStack {
                Text(VideoTimeFormatter.string(from: currentTime))
                Spacer()
                Text(VideoTimeFormatter.string(from: duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func playheadOffset(width: CGFloat) -> CGFloat {
        guard duration > 0, width > knob else { return 0 }
        return CGFloat(min(max(currentTime / duration, 0), 1)) * (width - knob)
    }
}
