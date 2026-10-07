import Photos
import SwiftUI

struct ImageDemoView: View {
    @State private var viewModel: ImageDemoViewModel
    @State private var isShowing3D = false

    init(viewModel: ImageDemoViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    imageArea
                        .frame(height: 420)
                    controls
                    landmarkList
                }
            }

            ChooseMediaButton(title: "Choose photo",
                              systemImage: "photo.on.rectangle",
                              mediaType: .image) { viewModel.select($0) }
        }
        .sheet(isPresented: $isShowing3D) {
            if let image = viewModel.image {
                Pose3DSheet(image: image)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowing3D = true
                } label: {
                    Label("3D", systemImage: "cube.transparent")
                }
                .disabled(viewModel.image == nil)
            }

            if let result = viewModel.result {
                let export = PoseExport(result: result)
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: export, preview: SharePreview(export.fileName)) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 8) {
            EngineSwitcher(engine: $viewModel.engine)

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


            statusLine
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if viewModel.isDetecting {
            HStack(spacing: 8) {
                ProgressView()
                Text("Detecting…")
            }
            .font(.footnote)
        } else if let result = viewModel.result {
            let total = result.poses.reduce(0) { $0 + $1.landmarks.count }
            let visible = result.poses.reduce(0) {
                $0 + $1.landmarks(minConfidence: viewModel.minConfidence).count
            }
            Text("\(result.engine.rawValue) · people: \(result.poses.count) · points: \(visible)/\(total) · \(Int(result.duration * 1000)) ms")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Landmarks

    /// Numbered left to right, like in the points table.
    private var personColors: [Int: Int] {
        guard let result = viewModel.result else { return [:] }
        return PersonMatcher.colorIndices(for: viewModel.engine,
                                          in: PersonMatcher.match([viewModel.engine: result]))
    }

    @ViewBuilder
    private var landmarkList: some View {
        if let result = viewModel.result {
            LandmarkBreakdownView(results: [viewModel.engine: result],
                                  engines: [viewModel.engine],
                                  minConfidence: viewModel.minConfidence,
                                  side: viewModel.side)
        }
    }

    // MARK: Image

    @ViewBuilder
    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.05)

                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)

                    PoseOverlayView(poses: viewModel.result?.poses ?? [],
                                    imageSize: image.size,
                                    mode: viewModel.overlayMode,
                                    minConfidence: viewModel.minConfidence,
                                    personColors: personColors,
                                    side: viewModel.side)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else if viewModel.isLoading {
                    ProgressView()
                } else {
                    ContentUnavailableView("No photo",
                                           systemImage: "figure.stand",
                                           description: Text("Choose photo with human"))
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        ImageDemoView(viewModel: ImageDemoViewModel())
            .padding()
    }
}
