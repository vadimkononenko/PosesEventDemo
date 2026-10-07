import SceneKit
import SwiftUI

/// A 3D skeleton the audience can rotate with a finger (SceneKit's built-in camera control).
/// Draws the first person of the result.
struct Pose3DSceneView: UIViewRepresentable {
    let result: Pose3DResult

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        // SwiftUI calls this on any state change: rebuilding the scene every time would
        // reset the camera the user has rotated.
        guard context.coordinator.shownResultID != result.id else { return }
        context.coordinator.shownResultID = result.id
        view.scene = Self.makeScene(for: result)
    }

    final class Coordinator {
        var shownResultID: UUID?
    }

    // MARK: Scene

    private static func makeScene(for result: Pose3DResult) -> SCNScene {
        let scene = SCNScene()

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0.2, 3.2)
        scene.rootNode.addChildNode(camera)

        guard let person = result.people.first else { return scene }

        let positions = Dictionary(person.joints.map { ($0.name, $0.position) },
                                   uniquingKeysWith: { first, _ in first })

        for joint in person.joints {
            if let parent = joint.parent, let parentPosition = positions[parent] {
                scene.rootNode.addChildNode(makeBone(from: parentPosition, to: joint.position))
            }
        }
        for joint in person.joints {
            scene.rootNode.addChildNode(makeJoint(joint))
        }

        // The floor is right under the lowest joint.
        let lowest = person.joints.map(\.position.y).min() ?? -0.9
        scene.rootNode.addChildNode(makeFloor(atHeight: lowest - 0.05))
        return scene
    }

    private static func makeJoint(_ joint: Pose3DJoint) -> SCNNode {
        let sphere = SCNSphere(radius: 0.035)
        sphere.firstMaterial?.diffuse.contents = color(for: joint.name)

        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(joint.position)
        return node
    }

    private static func color(for jointName: String) -> UIColor {
        let name = jointName.lowercased()
        if name.contains("left") { return .systemBlue }
        if name.contains("right") { return .systemOrange }
        return .white
    }

    private static func makeBone(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.012, height: CGFloat(simd_distance(start, end)))
        cylinder.firstMaterial?.diffuse.contents = UIColor.systemGray

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((start + end) / 2)
        // A cylinder is along the Y axis: turn that axis towards the end point.
        node.look(at: SCNVector3(end), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }

    private static func makeFloor(atHeight height: Float) -> SCNNode {
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = UIColor.tertiarySystemBackground

        let node = SCNNode(geometry: floor)
        node.position = SCNVector3(0, height, 0)
        return node
    }
}

private extension SCNVector3 {
    init(_ vector: SIMD3<Float>) {
        self.init(vector.x, vector.y, vector.z)
    }
}
