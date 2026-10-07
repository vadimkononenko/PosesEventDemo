import CoreGraphics
import Vision

/// A person's bounding box found by Vision. This is not a pose: just "somebody is here".
nonisolated struct PersonBox {
    /// Normalized, origin in the TOP-left corner (same convention as the landmarks).
    let rect: CGRect
    let confidence: Float
}

nonisolated struct VisionPersonDetector: Sendable {
    /// Synchronous: it is called from the background actor of the video pipeline.
    /// `image` must be upright.
    func detect(in image: CGImage) throws -> [PersonBox] {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false // the whole body, not only the torso

        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])

        return (request.results ?? []).map { observation in
            // Vision: origin in the bottom-left. Flip the Y axis.
            let box = observation.boundingBox
            let rect = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            return PersonBox(rect: rect, confidence: observation.confidence)
        }
    }
}
