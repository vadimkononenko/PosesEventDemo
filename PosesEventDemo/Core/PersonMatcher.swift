import CoreGraphics

/// One real person, seen by one or both engines.
struct MatchedPerson: Identifiable {
    /// 1-based, counted from left to right on the frame.
    let number: Int
    /// Index of this person's pose in the result of each engine that found them.
    let poseIndices: [PoseEngine: Int]

    var id: Int { number }
    /// Same color on every overlay and in the tables.
    var colorIndex: Int { number - 1 }
}

/// Engines return poses in their own order, and ML Kit returns only one pose.
/// So "the first pose" of ML Kit and of Vision can be different people. This matches
/// poses of different engines to the same person by where they are on the frame.
enum PersonMatcher {
    /// Landmarks below this confidence are ignored when finding where a person is.
    private static let reliableConfidence: Float = 0.3

    static func match(_ results: [PoseEngine: PoseDetectionResult]) -> [MatchedPerson] {
        struct Candidate {
            var poseIndices: [PoseEngine: Int]
            let box: CGRect
        }
        var candidates: [Candidate] = []

        // The engine that found more people goes first: its people are the reference.
        let engines = PoseEngine.allCases.sorted {
            (results[$0]?.poses.count ?? 0) > (results[$1]?.poses.count ?? 0)
        }

        for engine in engines {
            for (index, pose) in (results[engine]?.poses ?? []).enumerated() {
                guard let box = bounds(of: pose) else { continue }
                let center = CGPoint(x: box.midX, y: box.midY)

                // Same person: the center of this pose is inside someone already found
                // by another engine. With overlapping people, the closest center wins.
                let match = candidates.indices
                    .filter { candidates[$0].poseIndices[engine] == nil
                        && candidates[$0].box.insetBy(dx: -0.02, dy: -0.02).contains(center) }
                    .min { distance(candidates[$0].box, center) < distance(candidates[$1].box, center) }

                if let match {
                    candidates[match].poseIndices[engine] = index
                } else {
                    candidates.append(Candidate(poseIndices: [engine: index], box: box))
                }
            }
        }

        return candidates
            .sorted { $0.box.midX < $1.box.midX }
            .enumerated()
            .map { MatchedPerson(number: $0.offset + 1, poseIndices: $0.element.poseIndices) }
    }

    /// Pose index of `engine` -> color index of its person.
    static func colorIndices(for engine: PoseEngine, in people: [MatchedPerson]) -> [Int: Int] {
        var colors: [Int: Int] = [:]
        for person in people {
            if let index = person.poseIndices[engine] {
                colors[index] = person.colorIndex
            }
        }
        return colors
    }

    /// Box around the reliable landmarks of a pose, normalized.
    static func bounds(of pose: DetectedPose) -> CGRect? {
        let reliable = pose.landmarks(minConfidence: reliableConfidence)
        let points = (reliable.isEmpty ? pose.landmarks : reliable).map(\.position)
        guard let first = points.first else { return nil }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }
    }

    private static func distance(_ box: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(box.midX - point.x, box.midY - point.y)
    }
}
