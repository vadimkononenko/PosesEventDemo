import SwiftUI

struct CompareView: View {
    @State private var viewModel: CompareViewModel

    init(viewModel: CompareViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.image != nil {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(PoseEngine.allCases) { engine in
                                panel(for: engine)
                            }
                        }
                        controls
                        ComparisonTableView(results: viewModel.results,
                                            minConfidence: viewModel.minConfidence,
                                            runNumber: viewModel.runCount)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LandmarkBreakdownView(results: viewModel.results,
                                              minConfidence: viewModel.minConfidence,
                                              side: viewModel.side)
                    }
                }
            } else {
                // The image is handed over with `setImage(_:)` right after the screen appears.
                ProgressView().frame(maxHeight: .infinity)
            }
        }
    }

    private func panel(for engine: PoseEngine) -> some View {
        VStack(spacing: 6) {
            Text(engine.rawValue).font(.headline)

            if let image = viewModel.image {
                PosePhotoView(image: image,
                              poses: viewModel.results[engine]?.poses ?? [],
                              mode: viewModel.overlayMode,
                              minConfidence: viewModel.minConfidence,
                              personColors: PersonMatcher.colorIndices(for: engine,
                                                                       in: PersonMatcher.match(viewModel.results)),
                              side: viewModel.side)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = viewModel.errors[engine] {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if viewModel.results[engine] == nil, viewModel.isDetecting {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: $viewModel.overlayMode) {
                ForEach(OverlayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            BodySidePicker(side: $viewModel.side)

            HStack {
                Text("Confidence")
                Slider(value: $viewModel.minConfidence, in: 0...1)
                Text(String(format: "%.2f", viewModel.minConfidence))
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CompareView(viewModel: CompareViewModel())
            .padding()
    }
}
