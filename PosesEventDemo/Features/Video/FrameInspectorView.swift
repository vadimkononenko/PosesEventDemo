import SwiftUI

/// The numbers of the frame that is on the screen now, side by side for both engines.
/// The better value is green.
struct FrameInspectorView: View {
    let analysis: FrameAnalysis?
    let minConfidence: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current frame", systemImage: "viewfinder")
                .font(.subheadline.bold())

            if let analysis {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Color.clear.frame(height: 1)
                        ForEach(PoseEngine.allCases) { engine in
                            Text(engine.rawValue).font(.footnote.bold())
                        }
                    }
                    Divider()

                    // Not a race: ML Kit returns one pose by design, Vision returns everyone.
                    GridRow {
                        Text("People").font(.footnote).foregroundStyle(.secondary)
                        ForEach(PoseEngine.allCases) { engine in
                            MetricValue(text: analysis.poses[engine].map { "\($0.poses.count)" } ?? "…")
                        }
                    }
                    // Per person, otherwise more people would simply mean more points.
                    row("Points / person", goal: .higher, in: analysis) { result in
                        guard let first = result.poses.first else { return ("no pose", 0) }
                        let visible = result.poses.reduce(0) { $0 + $1.landmarks(minConfidence: minConfidence).count }
                        let perPerson = Int((Double(visible) / Double(result.poses.count)).rounded())
                        return ("\(perPerson) / \(first.landmarks.count)", Double(perPerson))
                    }
                    row("Confidence", goal: .higher, in: analysis) { result in
                        let values = result.poses.flatMap { $0.landmarks(minConfidence: minConfidence) }.map(\.confidence)
                        guard !values.isEmpty else { return ("—", nil) }
                        let rounded = (Double(values.reduce(0, +) / Float(values.count)) * 100).rounded() / 100
                        return (String(format: "%.2f", rounded), rounded)
                    }
                    row("Time", goal: .lower, in: analysis) { result in
                        let ms = Double(Int(result.duration * 1000))
                        return ("\(Int(ms)) ms", ms)
                    }
                }

                Text("People (Vision boxes): \(analysis.people.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Appears after the first frame.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    /// `metric` returns the shown text and the number used to pick the winner.
    private func row(_ title: String,
                     goal: MetricGoal,
                     in analysis: FrameAnalysis,
                     metric: @escaping (PoseDetectionResult) -> (text: String, value: Double?)) -> some View {
        let values = Dictionary(uniqueKeysWithValues: PoseEngine.allCases.compactMap { engine in
            analysis.poses[engine].flatMap { metric($0).value }.map { (engine, $0) }
        })
        let best = MetricWinner.winner(values, goal: goal)

        return GridRow {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            ForEach(PoseEngine.allCases) { engine in
                MetricValue(text: analysis.poses[engine].map { metric($0).text } ?? "…",
                            isWinner: best == engine)
            }
        }
    }
}
