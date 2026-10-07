import SwiftUI

/// A collapsible table of every body point: was it found, and with what confidence,
/// for each engine. Shows in numbers what the overlay only shows with transparency.
///
/// With several people one person is shown at a time. People are matched between the
/// engines by position (`PersonMatcher`), numbered left to right and colored like their skeletons.
struct LandmarkBreakdownView: View {
    let results: [PoseEngine: PoseDetectionResult]
    var engines: [PoseEngine] = PoseEngine.allCases
    var minConfidence: Float = 0
    /// Only the rows of one side of the body (plus the middle), like on the overlay.
    /// The side chosen on the screen. The table starts with it and follows its changes,
    /// but has its own picker too.
    var side: BodySide = .both

    @State private var isExpanded = false
    @State private var selectedNumber = 1
    @State private var tableSide: BodySide?

    /// The table's own choice, or the screen's side until the table picker is touched.
    private var shownSide: BodySide { tableSide ?? side }

    /// Below this a point is "weak": drawn semi-transparent on the overlay.
    private static let weakConfidence: Float = 0.5

    private static let groups: [(title: String, joints: [PoseJoint])] = [
        ("Head", [.nose, .leftEyeInner, .leftEye, .leftEyeOuter, .rightEyeInner, .rightEye, .rightEyeOuter,
                  .leftEar, .rightEar, .mouthLeft, .mouthRight]),
        ("Torso", [.neck, .leftShoulder, .rightShoulder, .root, .leftHip, .rightHip]),
        ("Arms", [.leftElbow, .rightElbow, .leftWrist, .rightWrist]),
        ("Hands", [.leftPinky, .rightPinky, .leftIndex, .rightIndex, .leftThumb, .rightThumb]),
        ("Legs", [.leftKnee, .rightKnee, .leftAnkle, .rightAnkle]),
        ("Feet", [.leftHeel, .rightHeel, .leftFootIndex, .rightFootIndex]),
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if people.count > 1 {
                    personPicker
                }
                BodySidePicker(side: Binding(get: { shownSide }, set: { tableSide = $0 }))
                table
                handsLine
                legend
            }
            .padding(.top, 8)
        } label: {
            Label(people.count > 1 ? "All points · \(people.count) people" : "All points",
                  systemImage: "list.bullet.rectangle")
                .font(.subheadline.bold())
        }
        .card()
        // A new choice on the screen wins over the table's own one.
        .onChange(of: side) { tableSide = nil }
    }

    // MARK: People

    private var people: [MatchedPerson] {
        PersonMatcher.match(results.filter { engines.contains($0.key) })
    }

    /// The chosen person; falls back to the first one when the frame has fewer people now.
    private var selectedPerson: MatchedPerson? {
        people.first { $0.number == selectedNumber } ?? people.first
    }

    /// The pose of the chosen person found by this engine, if it found them at all.
    private func pose(for engine: PoseEngine) -> DetectedPose? {
        guard let index = selectedPerson?.poseIndices[engine],
              let poses = results[engine]?.poses, index < poses.count else { return nil }
        return poses[index]
    }

    private var personPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(people) { person in
                    let isSelected = person.number == selectedPerson?.number
                    Button {
                        selectedNumber = person.number
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(PoseOverlayView.color(forPerson: person.colorIndex))
                                .frame(width: 10, height: 10)
                            Text("Person \(person.number)")
                        }
                        .font(.footnote.weight(isSelected ? .bold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.primary.opacity(0.12) : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Table

    private var table: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(height: 1)
                ForEach(engines) { engine in
                    Text(engine.rawValue).font(.footnote.bold())
                }
            }

            GridRow {
                Text("Found").font(.footnote).foregroundStyle(.secondary)
                ForEach(engines) { engine in
                    Text(summary(for: engine))
                        .font(.footnote.monospacedDigit().bold())
                }
            }
            Divider()

            ForEach(visibleGroups, id: \.title) { group in
                GridRow {
                    Text(group.title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .gridCellColumns(engines.count + 1)
                }

                ForEach(group.joints, id: \.self) { joint in
                    GridRow {
                        Text(Self.displayName(of: joint))
                            .font(.footnote)
                        ForEach(engines) { engine in
                            cell(engine: engine, joint: joint)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(engine: PoseEngine, joint: PoseJoint) -> some View {
        Group {
            if !engine.models(joint) {
                // The engine's model simply has no such point.
                Text("n/a").foregroundStyle(.tertiary)
            } else if results[engine] != nil {
                if let pose = pose(for: engine) {
                    if let landmark = pose[joint] {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color(for: landmark.confidence))
                                .frame(width: 6, height: 6)
                            Text(String(format: "%.2f", landmark.confidence))
                        }
                        // Hidden by the threshold slider: dimmed, like on the overlay.
                        .opacity(landmark.confidence < minConfidence ? 0.35 : 1)
                    } else {
                        Text("not found").foregroundStyle(.red)
                    }
                } else {
                    Text(people.isEmpty ? "no person" : "not tracked").foregroundStyle(.secondary)
                }
            } else {
                Text("…").foregroundStyle(.secondary)
            }
        }
        .font(.footnote.monospacedDigit())
    }

    /// "Vision hands: L 21 / 21 · R 18 / 21", only when Vision was asked for hands.
    @ViewBuilder
    private var handsLine: some View {
        if let pose = pose(for: .vision), !pose.hands.isEmpty {
            let sides = [BodySide.left, .right].filter { shownSide == .both || shownSide == $0 }
            let parts = sides.map { side -> String in
                let found = pose.hands.first { $0.side == side }?.landmarks
                    .filter { $0.confidence >= minConfidence }.count
                return "\(side == .left ? "L" : "R") " + (found.map { "\($0) / \(HandJoint.allCases.count)" } ?? "not found")
            }
            Text("**Vision hands:** " + parts.joined(separator: " · "))
                .font(.footnote.monospacedDigit())
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                legendDot(.green, "≥ 0.8")
                legendDot(.orange, "0.5 – 0.8")
                legendDot(.red, "< 0.5")
            }
            Text("**n/a** the engine has no such point · **not found** it has one, but did not detect it")
            if engines.contains(.mlKit) {
                Text("**ML Kit** confidence is *in-frame likelihood*: a hidden point inside the frame still scores high. **Vision** confidence drops when a point is not visible.")
            }
            if people.count > 1 {
                Text("People are numbered left to right, colors match the skeletons. **not tracked**: this engine did not find this person (ML Kit tracks only one).")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }

    // MARK: Helpers

    /// Groups with only the joints of the chosen side; empty groups are dropped.
    private var visibleGroups: [(title: String, joints: [PoseJoint])] {
        Self.groups.compactMap { group in
            let joints = group.joints.filter { $0.isVisible(for: shownSide) }
            return joints.isEmpty ? nil : (group.title, joints)
        }
    }

    /// "17 / 19 · 4 weak": found points out of the points the engine models.
    private func summary(for engine: PoseEngine) -> String {
        guard results[engine] != nil else { return "…" }
        guard let pose = pose(for: engine) else { return people.isEmpty ? "no person" : "not tracked" }

        let modeled = PoseJoint.allCases.filter { engine.models($0) && $0.isVisible(for: shownSide) }.count
        let found = pose.landmarks.filter { $0.joint.isVisible(for: shownSide) }
        let weak = found.filter { $0.confidence < Self.weakConfidence }.count
        return "\(found.count) / \(modeled)" + (weak > 0 ? " · \(weak) weak" : "")
    }

    private func color(for confidence: Float) -> Color {
        switch confidence {
        case ..<Self.weakConfidence: .red
        case ..<0.8: .orange
        default: .green
        }
    }

    /// `leftShoulder` -> `left shoulder`
    private static func displayName(of joint: PoseJoint) -> String {
        joint.rawValue.reduce(into: "") { name, character in
            if character.isUppercase { name += " " }
            name += character.lowercased()
        }
    }
}

private extension PoseEngine {
    /// Whether the engine's model has this point at all.
    func models(_ joint: PoseJoint) -> Bool {
        switch self {
        case .mlKit: !PoseJoint.visionOnly.contains(joint)
        case .vision: !PoseJoint.mlKitOnly.contains(joint)
        }
    }
}
