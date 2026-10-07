import SwiftUI

/// What the whole video looked like for each engine. The better value is green.
struct VideoAnalysisSummaryView: View {
    let result: VideoAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Summary", systemImage: "chart.bar.doc.horizontal")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(result.frames.count) frames · \(Int(result.configuration.framesPerSecond)) FPS")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Color.clear.frame(height: 1)
                    ForEach(PoseEngine.allCases) { engine in
                        Text(engine.rawValue).font(.footnote.bold())
                    }
                }
                Divider()

                row("Pose found", goal: .higher) {
                    let count = result.framesWithPose(for: $0)
                    return ("\(count) / \(result.frames.count)", Double(count))
                }
                row("Per frame", goal: .lower) {
                    let ms = Double(Int(result.averageTime(for: $0) * 1000))
                    return ("\(Int(ms)) ms", ms)
                }
                row("Total", goal: .lower) {
                    let seconds = (result.totalTime(for: $0) * 10).rounded() / 10
                    return (String(format: "%.1f s", seconds), seconds)
                }
            }
        }
        .card()
    }

    private func row(_ title: String,
                     goal: MetricGoal,
                     metric: @escaping (PoseEngine) -> (text: String, value: Double)) -> some View {
        let values = Dictionary(uniqueKeysWithValues: PoseEngine.allCases.map { ($0, metric($0).value) })
        let best = MetricWinner.winner(values, goal: goal)

        return GridRow {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            ForEach(PoseEngine.allCases) { engine in
                MetricValue(text: metric(engine).text, isWinner: best == engine)
            }
        }
    }
}
