import SwiftUI

/// What to draw over the video. Everything here is instant, no new analysis is needed.
struct OverlayControlsView: View {
    @Binding var settings: VideoOverlaySettings

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    layerToggle("Boxes", systemImage: "person.crop.rectangle", isOn: $settings.showsBoxes)
                    layerToggle("Skeleton", systemImage: "figure.arms.open", isOn: $settings.showsSkeleton)
                    layerToggle("Landmarks", systemImage: "point.3.connected.trianglepath.dotted", isOn: $settings.showsLandmarks)
                }
            }
            .scrollIndicators(.hidden)

            BodySidePicker(side: $settings.side)

            HStack {
                Text("Confidence")
                Slider(value: $settings.minConfidence, in: 0...1)
                Text(String(format: "%.2f", settings.minConfidence))
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private func layerToggle(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
