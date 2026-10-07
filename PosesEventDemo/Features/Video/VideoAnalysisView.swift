import Photos
import SwiftUI

/// Video: choose -> settings -> live analysis by both engines -> playback with the results.
struct VideoAnalysisView: View {
    @State private var viewModel: VideoAnalysisViewModel

    init(viewModel: VideoAnalysisViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let session = viewModel.state.session {
                workspace(for: session)
            } else {
                selection
            }
        }
        .toolbar {
            if viewModel.state.session != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ChooseMediaButton(title: "Change video",
                                      systemImage: "video.badge.plus",
                                      mediaType: .video,
                                      isProminent: false) { viewModel.select($0) }
                        .disabled(viewModel.state.isAnalyzing)
                }
            }
        }
        .onDisappear { viewModel.pause() }
    }

    // MARK: Nothing chosen

    private var selection: some View {
        VStack(spacing: 16) {
            if viewModel.state.isImporting {
                ProgressView("Reading the video…")
                    .frame(maxHeight: .infinity)
            } else {
                ContentUnavailableView("No video",
                                       systemImage: "figure.walk.motion",
                                       description: Text("Choose a video with a person. Both engines will track it frame by frame."))
                    .frame(maxHeight: .infinity)

                if case .failed(let failure) = viewModel.state {
                    Text(failure.message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ChooseMediaButton(title: "Choose video",
                                  systemImage: "video.badge.plus",
                                  mediaType: .video) { viewModel.select($0) }
            }
        }
    }

    // MARK: Video chosen

    private func workspace(for session: VideoSession) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // One under the other: each video gets the full width.
                VStack(spacing: 12) {
                    ForEach(PoseEngine.allCases) { engine in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(engine.rawValue).font(.headline)
                            VideoAnalysisSurface(player: session.player,
                                                 videoSize: session.video.displaySize,
                                                 analysis: viewModel.state.displayedAnalysis,
                                                 engine: engine,
                                                 settings: viewModel.overlaySettings,
                                                 isAnalyzing: viewModel.state.isAnalyzing)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                metadata(of: session.video)

                phaseContent(for: session)
            }
        }
    }

    private func metadata(of video: ImportedVideo) -> some View {
        let size = video.displaySize
        return Text("\(VideoTimeFormatter.string(from: video.duration)) · \(Int(size.width))×\(Int(size.height)) · \(Int(video.nominalFrameRate.rounded())) FPS")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func phaseContent(for session: VideoSession) -> some View {
        switch viewModel.state {
        case .ready:
            settings(for: session.video)

        case .analyzing(let analysis):
            AnalysisProgressView(progress: analysis.progress?.fractionCompleted ?? 0,
                                 analyzedFrameCount: analysis.progress?.analyzedFrameCount ?? 0,
                                 currentTime: analysis.progress?.latest.time,
                                 onCancel: viewModel.cancelAnalysis)
            OverlayControlsView(settings: $viewModel.overlaySettings)
            FrameInspectorView(analysis: analysis.progress?.latest,
                               minConfidence: viewModel.overlaySettings.minConfidence)
            LandmarkBreakdownView(results: analysis.progress?.latest.poses ?? [:],
                                  minConfidence: viewModel.overlaySettings.minConfidence,
                                  side: viewModel.overlaySettings.side)

        case .completed(let analysis):
            PlaybackControlsView(isPlaying: analysis.playback.isPlaying,
                                 currentTime: analysis.playback.time,
                                 duration: session.video.duration,
                                 onTogglePlayback: viewModel.togglePlayback,
                                 onSeek: viewModel.seek)
            AnalysisTimelineView(frames: analysis.result.frames,
                                 currentTime: analysis.playback.time,
                                 duration: session.video.duration,
                                 onSeek: viewModel.seek)
            OverlayControlsView(settings: $viewModel.overlaySettings)
            FrameInspectorView(analysis: analysis.currentAnalysis,
                               minConfidence: viewModel.overlaySettings.minConfidence)
            VideoAnalysisSummaryView(result: analysis.result)
            LandmarkBreakdownView(results: analysis.currentAnalysis?.poses ?? [:],
                                  minConfidence: viewModel.overlaySettings.minConfidence,
                                  side: viewModel.overlaySettings.side)

            Button(action: viewModel.prepareForReanalysis) {
                Label("Analyze again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

        case .failed(let failure):
            Text(failure.message)
                .font(.footnote)
                .foregroundStyle(.red)
            settings(for: session.video)

        case .cancelled:
            Text("The partial results were discarded. Change the settings and start again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            settings(for: session.video)

        case .empty, .importing:
            EmptyView()
        }
    }

    private func settings(for video: ImportedVideo) -> some View {
        AnalysisSettingsView(configuration: $viewModel.configuration,
                             video: video,
                             onStart: viewModel.startAnalysis)
    }
}

#Preview {
    NavigationStack {
        VideoAnalysisView(viewModel: VideoAnalysisViewModel())
            .padding()
    }
}
