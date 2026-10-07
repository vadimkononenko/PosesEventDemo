import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Image", systemImage: "photo") {
                NavigationStack {
                    ImageDemoView(viewModel: ImageDemoViewModel())
                        .padding()
                        .navigationTitle("Image")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Video", systemImage: "video") {
                NavigationStack {
                    VideoAnalysisView(viewModel: VideoAnalysisViewModel())
                        .padding()
                        .navigationTitle("Video")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Squats", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    SquatsView(viewModel: SquatsViewModel())
                        .padding()
                        .navigationTitle("Squats")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Compare", systemImage: "rectangle.split.2x1") {
                NavigationStack {
                    // Prepared cases; each one opens both engines side by side.
                    LimitationsView()
                        .navigationTitle("Compare")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

#Preview {
    RootView()
}
