import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let onTogglePlayback: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button {
                onSeek(max(currentTime - 5, 0))
            } label: {
                Image(systemName: "gobackward.5")
            }
            .accessibilityLabel("Back 5 seconds")

            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                onSeek(min(currentTime + 5, duration))
            } label: {
                Image(systemName: "goforward.5")
            }
            .accessibilityLabel("Forward 5 seconds")
        }
        .font(.title2)
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .frame(maxWidth: .infinity)
    }
}
