import CoreGraphics
import Foundation

/// The whole "algorithm" of the squat counter. Shown on the screen, so it can be explained.
enum SquatRules {
    /// The knee bends below this: the person is down.
    static let downAngle = 100.0
    /// The knee straightens above this: the person is up again, one repetition.
    static let upAngle = 160.0
    /// Points less sure than this are not used for the angles.
    static let minConfidence: Float = 0.3

    // Checks: a bent knee alone is not a squat (a roll or a fall bends it too).

    /// The torso (mid shoulders -> mid hips) may lean at most this much from vertical.
    static let maxTorsoTilt = 45.0
    /// From standing to standing again, seconds.
    static let minRepDuration = 0.5
    static let maxRepDuration = 6.0
}

enum KneeAngle {
    /// Angle in the knee (hip – knee – ankle) in degrees: ~180 standing, ~90 in a deep squat.
    /// Takes the leg whose three points the engine is most sure about (on a side view one leg
    /// is often hidden). `nil` if neither leg is usable.
    static func degrees(in pose: DetectedPose, imageSize: CGSize) -> Double? {
        let legs: [(hip: PoseJoint, knee: PoseJoint, ankle: PoseJoint)] = [
            (.leftHip, .leftKnee, .leftAnkle),
            (.rightHip, .rightKnee, .rightAnkle),
        ]

        let candidates = legs.compactMap { leg -> (score: Float, angle: Double)? in
            guard let hip = pose[leg.hip], let knee = pose[leg.knee], let ankle = pose[leg.ankle],
                  min(hip.confidence, knee.confidence, ankle.confidence) >= SquatRules.minConfidence,
                  let angle = angle(hip.position, knee.position, ankle.position, imageSize: imageSize) else {
                return nil
            }
            return (hip.confidence + knee.confidence + ankle.confidence, angle)
        }
        return candidates.max { $0.score < $1.score }?.angle
    }

    /// Angle at `vertex`, computed in PIXELS: in normalized coordinates X and Y have
    /// different scales (unless the frame is square) and the angle would be distorted.
    static func angle(_ a: CGPoint, _ vertex: CGPoint, _ c: CGPoint, imageSize: CGSize) -> Double? {
        let ax = Double((a.x - vertex.x) * imageSize.width)
        let ay = Double((a.y - vertex.y) * imageSize.height)
        let cx = Double((c.x - vertex.x) * imageSize.width)
        let cy = Double((c.y - vertex.y) * imageSize.height)

        let lengths = hypot(ax, ay) * hypot(cx, cy)
        guard lengths > 0 else { return nil }
        return acos(min(1, max(-1, (ax * cx + ay * cy) / lengths))) * 180 / .pi
    }
}

enum TorsoTilt {
    /// How far the torso leans from vertical, degrees: 0 upright, 90 lying, 180 upside down.
    /// Uses the middle of the visible shoulders and of the visible hips. `nil` if either is missing.
    static func degrees(in pose: DetectedPose, imageSize: CGSize) -> Double? {
        guard let shoulders = middle(of: [.leftShoulder, .rightShoulder], in: pose),
              let hips = middle(of: [.leftHip, .rightHip], in: pose) else { return nil }

        // From hips up to shoulders, in pixels. "Up" on the screen is negative Y.
        let dx = Double((shoulders.x - hips.x) * imageSize.width)
        let dy = Double((shoulders.y - hips.y) * imageSize.height)
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        return acos(min(1, max(-1, -dy / length))) * 180 / .pi
    }

    private static func middle(of joints: [PoseJoint], in pose: DetectedPose) -> CGPoint? {
        let points = joints.compactMap { pose[$0] }
            .filter { $0.confidence >= SquatRules.minConfidence }
            .map(\.position)
        guard !points.isEmpty else { return nil }
        return CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                       y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
    }
}

/// Why a down-and-up movement was not counted as a squat.
enum RejectReason: String, CaseIterable {
    case torsoTilted = "torso tilted"
    case tooFast = "too fast"
    case tooSlow = "too slow"
}

/// Two states, up and down. A repetition is counted when the person comes back up.
/// The thresholds to go down and to come up are far apart (hysteresis), so the jitter
/// of the angle around one value does not count extra repetitions.
///
/// With checks enabled, a down-and-up only counts if it also looks like a squat:
/// the torso stays upright and the movement takes a reasonable time.
struct SquatCounter {
    let checksEnabled: Bool

    private(set) var isDown = false
    private(set) var reps = 0
    private(set) var rejected: [RejectReason: Int] = [:]

    /// The last moment the person was standing: the start of the current attempt.
    private var standingTime: TimeInterval?
    /// The largest torso tilt since then.
    private var maxTilt = 0.0

    var rejectedTotal: Int { rejected.values.reduce(0, +) }

    init(checksEnabled: Bool = true) {
        self.checksEnabled = checksEnabled
    }

    /// `nil` angles (points not visible on this frame) keep the current state.
    mutating func update(time: TimeInterval, kneeAngle: Double?, torsoTilt: Double?) {
        if let torsoTilt { maxTilt = max(maxTilt, torsoTilt) }
        guard let angle = kneeAngle else { return }

        if !isDown {
            if angle > SquatRules.upAngle {
                startAttempt(at: time, tilt: torsoTilt)
            } else if angle < SquatRules.downAngle {
                isDown = true
            }
        } else if angle > SquatRules.upAngle {
            isDown = false
            if let reason = rejection(at: time) {
                rejected[reason, default: 0] += 1
            } else {
                reps += 1
            }
            startAttempt(at: time, tilt: torsoTilt)
        }
    }

    private mutating func startAttempt(at time: TimeInterval, tilt: Double?) {
        standingTime = time
        maxTilt = tilt ?? 0
    }

    private func rejection(at time: TimeInterval) -> RejectReason? {
        guard checksEnabled else { return nil }
        if maxTilt > SquatRules.maxTorsoTilt { return .torsoTilted }

        // Unknown when the video starts mid-squat: then the duration is not checked.
        guard let standingTime else { return nil }
        let duration = time - standingTime
        if duration < SquatRules.minRepDuration { return .tooFast }
        if duration > SquatRules.maxRepDuration { return .tooSlow }
        return nil
    }
}

/// Which person to count on a frame, for each engine.
///
/// ML Kit always returns one person; Vision returns everyone in no particular order.
/// To compare the engines fairly, Vision counts the same person ML Kit tracks.
enum SquatSubject {
    /// - Returns: the pose index for each engine that found the person, and the person's center
    ///   (pass it as `previousCenter` for the next frame).
    static func select(in frame: FrameAnalysis,
                       previousCenter: CGPoint?) -> (indices: [PoseEngine: Int], center: CGPoint?) {
        var indices: [PoseEngine: Int] = [:]
        let mlKitPoses = frame.poses[.mlKit]?.poses ?? []
        let visionPoses = frame.poses[.vision]?.poses ?? []

        if !mlKitPoses.isEmpty {
            indices[.mlKit] = 0
        }

        if !mlKitPoses.isEmpty,
           let person = PersonMatcher.match(frame.poses).first(where: { $0.poseIndices[.mlKit] == 0 }),
           let visionIndex = person.poseIndices[.vision] {
            // The same person as ML Kit, matched by position.
            indices[.vision] = visionIndex
        } else if let fallback = fallbackIndex(in: visionPoses, near: previousCenter) {
            // ML Kit sees nobody here: keep following whoever was counted before.
            indices[.vision] = fallback
        }

        let chosen = indices[.mlKit].map { mlKitPoses[$0] } ?? indices[.vision].map { visionPoses[$0] }
        let center = chosen.flatMap(PersonMatcher.bounds(of:)).map { CGPoint(x: $0.midX, y: $0.midY) }
        return (indices, center)
    }

    /// The pose closest to the previous center, or the largest one without a previous center.
    private static func fallbackIndex(in poses: [DetectedPose], near previousCenter: CGPoint?) -> Int? {
        let boxes = poses.enumerated().compactMap { index, pose in
            PersonMatcher.bounds(of: pose).map { (index: index, box: $0) }
        }

        if let previousCenter {
            return boxes.min {
                hypot($0.box.midX - previousCenter.x, $0.box.midY - previousCenter.y)
                    < hypot($1.box.midX - previousCenter.x, $1.box.midY - previousCenter.y)
            }?.index
        }
        return boxes.max { $0.box.width * $0.box.height < $1.box.width * $1.box.height }?.index
    }
}

/// Knee angle, state and counts so far for every analyzed frame, for one engine.
struct SquatTimeline {
    struct Sample {
        let time: TimeInterval
        let kneeAngle: Double?
        let isDown: Bool
        let reps: Int
        let rejectedTotal: Int
    }

    /// Sorted by time, one per analyzed frame.
    let samples: [Sample]
    let rejected: [RejectReason: Int]

    var totalReps: Int { samples.last?.reps ?? 0 }
    var totalRejected: Int { rejected.values.reduce(0, +) }

    /// The last sample at or before `time`: the count never runs ahead of the video.
    func sample(at time: TimeInterval) -> Sample? {
        var low = 0
        var high = samples.count
        while low < high {
            let middle = (low + high) / 2
            if samples[middle].time <= time + 0.001 {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? samples[low - 1] : samples.first
    }
}

/// The squat count of a whole video for both engines, on the same person.
struct SquatAnalysis {
    let timelines: [PoseEngine: SquatTimeline]
    /// Frame index -> engine -> index of the counted pose. Used to draw only that person.
    let subject: [Int: [PoseEngine: Int]]

    init(frames: [FrameAnalysis], checksEnabled: Bool) {
        var counters = Dictionary(uniqueKeysWithValues: PoseEngine.allCases.map {
            ($0, SquatCounter(checksEnabled: checksEnabled))
        })
        var samples: [PoseEngine: [SquatTimeline.Sample]] = [:]
        var subject: [Int: [PoseEngine: Int]] = [:]
        var center: CGPoint?

        for frame in frames {
            let selection = SquatSubject.select(in: frame, previousCenter: center)
            center = selection.center ?? center
            subject[frame.index] = selection.indices

            for engine in PoseEngine.allCases {
                var kneeAngle: Double?
                var torsoTilt: Double?
                if let result = frame.poses[engine], let index = selection.indices[engine], index < result.poses.count {
                    let pose = result.poses[index]
                    kneeAngle = KneeAngle.degrees(in: pose, imageSize: result.imageSize)
                    torsoTilt = TorsoTilt.degrees(in: pose, imageSize: result.imageSize)
                }

                counters[engine]?.update(time: frame.time, kneeAngle: kneeAngle, torsoTilt: torsoTilt)
                let counter = counters[engine]!
                samples[engine, default: []].append(SquatTimeline.Sample(time: frame.time,
                                                                         kneeAngle: kneeAngle,
                                                                         isDown: counter.isDown,
                                                                         reps: counter.reps,
                                                                         rejectedTotal: counter.rejectedTotal))
            }
        }

        self.subject = subject
        timelines = Dictionary(uniqueKeysWithValues: PoseEngine.allCases.map { engine in
            (engine, SquatTimeline(samples: samples[engine] ?? [], rejected: counters[engine]?.rejected ?? [:]))
        })
    }
}
