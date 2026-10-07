import Foundation
import simd

/// A joint of the 3D pose. The position is in meters, relative to the pelvis (`root`), Y goes up.
nonisolated struct Pose3DJoint {
    let name: String
    /// `nil` for the root: it is the start of the chain.
    let parent: String?
    let position: SIMD3<Float>
}

nonisolated struct Pose3DPerson {
    let joints: [Pose3DJoint]
    let bodyHeightMeters: Double
    /// `true`: measured by the device (depth data). `false`: a reference height was assumed.
    let isHeightMeasured: Bool
}

nonisolated struct Pose3DResult {
    /// Identifies this result, so the 3D scene is rebuilt only when the result changes.
    let id = UUID()
    let people: [Pose3DPerson]
    let duration: TimeInterval
}
