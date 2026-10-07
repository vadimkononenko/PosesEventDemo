import Photos
import SwiftUI

/// A practical example on top of the landmarks: count squats in a video.
/// landmarks -> knee angle -> two states (up / down) -> repetitions.
/// All logic lives in `SquatsViewModel`; this view only draws it.
struct SquatsView: View {
    @State private var viewModel: SquatsViewModel

    init(viewModel: SquatsViewModel) {
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
                ContentUnavailableView("Count squats",
                                       systemImage: "figure.strengthtraining.traditional",
                                       description: Text("Choose a video of squats. One person, full height, a side view works best."))
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
                        enginePanel(engine, session: session)
                    }
                }

                phaseContent(for: session)
            }
        }
    }

    private func enginePanel(_ engine: PoseEngine, session: VideoSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(engine.rawValue).font(.headline)
                if engine == .vision {
                    Text("same person as ML Kit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack(alignment: .topTrailing) {
                VideoAnalysisSurface(player: session.player,
                                     videoSize: session.video.displaySize,
                                     analysis: viewModel.displayedFrame,
                                     engine: engine,
                                     settings: skeletonOnly,
                                     isAnalyzing: viewModel.state.isAnalyzing)

                if case .completed = viewModel.state {
                    counterBadge(for: viewModel.currentSample(for: engine))
                        .padding(10)
                }
            }
        }
    }

    /// Only the skeleton: the counter should be readable over the video.
    private var skeletonOnly: VideoOverlaySettings {
        var settings = VideoOverlaySettings()
        settings.showsBoxes = false
        return settings
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

            Toggle(isOn: $viewModel.checksEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Squat checks")
                    Text("Without them any knee bend counts, even a roll or a fall.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)

            totals

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
            Text("The partial results were discarded. Start again when ready.")
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

    // MARK: Counter

    /// Repetitions so far, state and knee angle at the current moment of the video.
    private func counterBadge(for sample: SquatTimeline.Sample?) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(sample?.reps ?? 0)")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
            Text(sample?.isDown == true ? "DOWN" : "UP")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(sample?.isDown == true ? Color.orange : Color.green, in: Capsule())
            Text(sample?.kneeAngle.map { "knee \(Int($0))°" } ?? "knee —")
                .font(.caption.monospacedDigit())
            if let rejected = sample?.rejectedTotal, rejected > 0 {
                Text("✕ \(rejected) rejected")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.red.mix(with: .white, by: 0.4))
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Repetitions", systemImage: "figure.strengthtraining.traditional")
                .font(.subheadline.bold())

            HStack {
                ForEach(PoseEngine.allCases) { engine in
                    VStack(spacing: 2) {
                        Text("\(viewModel.timeline(for: engine)?.totalReps ?? 0)")
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        Text(engine.rawValue).font(.footnote.bold())

                        if !viewModel.foundLegs(for: engine) {
                            Text("legs not found").font(.caption).foregroundStyle(.red)
                        } else if let rejected = viewModel.timeline(for: engine)?.totalRejected, rejected > 0 {
                            Text("\(rejected) rejected")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                            Text(viewModel.rejectionSummary(for: engine))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Knee angle = hip – knee – ankle. Down: below \(Int(SquatRules.downAngle))°. Up: above \(Int(SquatRules.upAngle))°, one repetition each time.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.checksEnabled {
                Text("Checks: torso within \(Int(SquatRules.maxTorsoTilt))° of vertical, \(String(format: "%.1f", SquatRules.minRepDuration))–\(Int(SquatRules.maxRepDuration)) s per repetition.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

#Preview {
    NavigationStack {
        SquatsView(viewModel: SquatsViewModel())
            .padding()
    }
}
