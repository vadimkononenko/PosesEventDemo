import Foundation

/// A prepared photo that shows one limitation of pose detection.
/// The files live in `Resources/TestCases/` and are named after `fileName`.
struct LimitationCase: Identifiable, Hashable {
    let fileName: String
    let title: String
    /// What happens in this case: one short line.
    let problem: String
    /// What to look at on the screen: one short line.
    let lookAt: String

    var id: String { fileName }

    /// `nil` if the file was not added to the app target yet.
    var url: URL? {
        let name = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension

        // Depending on how the folder was added, the file may or may not keep its subfolder.
        for subdirectory in [nil, "TestCases", "Resources/TestCases"] {
            if let url = Bundle.main.url(forResource: name,
                                         withExtension: fileExtension,
                                         subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }
}

extension LimitationCase {
    static let images: [LimitationCase] = [
        LimitationCase(fileName: "01_front.jpeg", title: "Front view",
                       problem: "Baseline, ideal conditions",
                       lookAt: "Engines agree; ML Kit adds face, hand, foot points"),
        LimitationCase(fileName: "02_side.jpeg", title: "Side view",
                       problem: "Far arm and leg hidden",
                       lookAt: "Missing or low-confidence points on the far side"),
        LimitationCase(fileName: "03_back.jpeg", title: "Back view",
                       problem: "No face visible",
                       lookAt: "Left and right swapped, unstable head points"),
        LimitationCase(fileName: "04_sitting.jpeg", title: "Sitting",
                       problem: "Folded legs, furniture in the way",
                       lookAt: "Hips and knees"),
        LimitationCase(fileName: "05_squat.jpeg", title: "Squat",
                       problem: "Limbs overlap the torso",
                       lookAt: "Knee and hip positions"),
        LimitationCase(fileName: "06_occlusion.jpeg", title: "Occlusion",
                       problem: "Part of the body is covered",
                       lookAt: "Guessed points vs dropped points"),
        LimitationCase(fileName: "07_multiple_people.jpeg", title: "Multiple people",
                       problem: "Several people in the frame",
                       lookAt: "Vision finds all, ML Kit only one"),
        LimitationCase(fileName: "08_small_person.jpeg", title: "Small / distant person",
                       problem: "Person fills a small part of the frame",
                       lookAt: "Precision drops or nobody is found"),
    ]
}
