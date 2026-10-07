import SwiftUI

/// Side-by-side numbers for the two engines on the same photo. The better value is green.
struct ComparisonTableView: View {
    let results: [PoseEngine: PoseDetectionResult]
    var minConfidence: Float = 0
    /// Shown as "Run N" from the second run on, so it is clear the numbers are new.
    var runNumber = 1

    /// ML Kit has three points per hand: pinky, index, thumb.
    private static let mlKitHandJoints: Set<PoseJoint> = [
        .leftPinky, .rightPinky, .leftIndex, .rightIndex, .leftThumb, .rightThumb,
    ]
    private static let visionHandPoints = 2 * HandJoint.allCases.count

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Group {
                        if runNumber > 1 {
                            Text("Run \(runNumber)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    ForEach(PoseEngine.allCases) { engine in
                        Text(engine.rawValue).font(.subheadline.bold())
                    }
                }
                Divider()

                row("Time", goal: .lower) {
                    let ms = Double(Int($0.duration * 1000))
                    return ("\(Int(ms)) ms", ms)
                }
                // Per person, otherwise more people would simply mean more points.
                row("Points / person", goal: .higher) {
                    guard let first = $0.poses.first else { return ("no pose", 0) }
                    let visible = $0.visiblePointCount(minConfidence: minConfidence)
                    let perPerson = Int((Double(visible) / Double($0.poses.count)).rounded())
                    return ("\(perPerson) / \(first.landmarks.count)", Double(perPerson))
                }
                row("Confidence", goal: .higher) {
                    guard let value = $0.averageConfidence(minConfidence: minConfidence) else { return ("—", nil) }
                    let rounded = (Double(value) * 100).rounded() / 100
                    return (String(format: "%.2f", rounded), rounded)
                }
                row("People") { ("\($0.poses.count)", nil) }

                // Same hands, very different detail: 6 points against 42.
                row("Hand points", goal: .higher) { result in
                    if result.engine == .vision {
                        let found = result.poses.flatMap(\.hands).flatMap(\.landmarks)
                            .filter { $0.confidence >= minConfidence }.count
                        return ("\(found) / \(Self.visionHandPoints)", Double(found))
                    }
                    let found = result.poses.flatMap { $0.landmarks(minConfidence: minConfidence) }
                        .filter { Self.mlKitHandJoints.contains($0.joint) }.count
                    return ("\(found) / \(Self.mlKitHandJoints.count)", Double(found))
                }

                GridRow {
                    label("Unique points")
                    MetricValue(text: "\(PoseJoint.mlKitOnly.count)")
                    MetricValue(text: "\(PoseJoint.visionOnly.count + Self.visionHandPoints)")
                }

                if let offset = averageOffset {
                    GridRow {
                        label("Offset")
                        MetricValue(text: String(format: "%.1f %% of diagonal", offset * 100))
                            .gridCellColumns(2)
                    }
                }
            }

            Text("Unique: **ML Kit** face, feet · **Vision** neck, pelvis, 21 points per hand")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func label(_ title: String) -> some View {
        Text(title).font(.footnote).foregroundStyle(.secondary)
    }

    /// `metric` returns the shown text and the number used to pick the winner.
    private func row(_ title: String,
                     goal: MetricGoal? = nil,
                     metric: @escaping (PoseDetectionResult) -> (text: String, value: Double?)) -> some View {
        let values = Dictionary(uniqueKeysWithValues: PoseEngine.allCases.compactMap { engine in
            results[engine].flatMap { metric($0).value }.map { (engine, $0) }
        })
        let best = goal.flatMap { MetricWinner.winner(values, goal: $0) }

        return GridRow {
            label(title)
            ForEach(PoseEngine.allCases) { engine in
                if let result = results[engine] {
                    MetricValue(text: metric(result).text, isWinner: best == engine)
                } else {
                    MetricValue(text: "…")
                }
            }
        }
    }

    /// Mean distance between the same joints found by both engines (first person only),
    /// as a fraction of the image diagonal. Measured in pixels, not in normalized units,
    /// otherwise X and Y would have different weights.
    private var averageOffset: Double? {
        guard let mlKit = results[.mlKit], let vision = results[.vision],
              let first = mlKit.poses.first, let second = vision.poses.first else { return nil }

        let size = mlKit.imageSize
        let diagonal = hypot(size.width, size.height)
        guard diagonal > 0 else { return nil }

        let distances: [Double] = first.landmarks(minConfidence: minConfidence).compactMap { landmark in
            guard let other = second[landmark.joint], other.confidence >= minConfidence else { return nil }
            let dx = (landmark.position.x - other.position.x) * size.width
            let dy = (landmark.position.y - other.position.y) * size.height
            return hypot(dx, dy)
        }
        guard !distances.isEmpty else { return nil }
        return distances.reduce(0, +) / Double(distances.count) / diagonal
    }
}

private extension PoseDetectionResult {
    func visiblePointCount(minConfidence: Float) -> Int {
        poses.reduce(0) { $0 + $1.landmarks(minConfidence: minConfidence).count }
    }

    func averageConfidence(minConfidence: Float) -> Float? {
        let values = poses.flatMap { $0.landmarks(minConfidence: minConfidence) }.map(\.confidence)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }
}
