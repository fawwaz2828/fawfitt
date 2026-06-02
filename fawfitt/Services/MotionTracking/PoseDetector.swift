import CoreGraphics
import CoreML
import Foundation
import Vision

/// Snapshot of a detected human body pose with normalized image coordinates
/// (Vision returns points in `[0, 1]`, origin at bottom-left).
struct DetectedPose: Sendable, Equatable {
    /// Joint position in normalized Vision coordinates (origin bottom-left).
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    /// Per-joint confidence in `[0, 1]`.
    let confidences: [VNHumanBodyPoseObservation.JointName: Float]
    let timestamp: TimeInterval
    /// Size of the *oriented* source image (after `orientation` is applied) in pixels.
    /// Lets the overlay replicate the camera preview's aspect-fill crop so the skeleton
    /// lines up with the body instead of floating against the raw normalized space.
    let sourceSize: CGSize
    /// Flattened `VNHumanBodyPoseObservation.keypointsMultiArray()` output (54 = 3×18
    /// values, x/y/confidence per joint) in Apple's fixed joint order. Sendable so it can
    /// cross the detached detection task; rebuilt into an MLMultiArray for the CoreML
    /// Action Classifier. `nil` if Vision couldn't produce the keypoints array.
    let keypoints: [Float]?

    func point(_ name: VNHumanBodyPoseObservation.JointName, minConfidence: Float) -> CGPoint? {
        guard let confidence = confidences[name], confidence >= minConfidence else { return nil }
        return joints[name]
    }
}

extension MLMultiArray {
    /// Reads every element (raster order) into a Swift `[Float]`. Used to transport the
    /// keypoints array out of Vision as a Sendable value.
    func toFloatArray() -> [Float] {
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count { out[i] = self[i].floatValue }
        return out
    }
}

/// Wraps `VNDetectHumanBodyPoseRequest` and exposes a synchronous detect call
/// the caller is expected to run on a background queue.
final class PoseDetector {

    /// Joints below this confidence are dropped from the returned pose.
    let minimumConfidence: Float

    init(minimumConfidence: Float = 0.3) {
        self.minimumConfidence = minimumConfidence
    }

    /// Run pose detection on a single CVPixelBuffer. Returns `nil` if no
    /// person is detected. Thread-safe to call from a background queue.
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, timestamp: TimeInterval) throws -> DetectedPose? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }
        let recognized = try observation.recognizedPoints(.all)

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var confidences: [VNHumanBodyPoseObservation.JointName: Float] = [:]
        joints.reserveCapacity(recognized.count)
        confidences.reserveCapacity(recognized.count)

        for (key, point) in recognized {
            guard point.confidence >= minimumConfidence else { continue }
            joints[key] = point.location
            confidences[key] = point.confidence
        }

        if joints.isEmpty { return nil }

        // Apple's keypointsMultiArray() yields the exact (1,3,18) layout the Create ML
        // Action Classifier was trained on — flatten it so the order always matches.
        let keypoints = (try? observation.keypointsMultiArray())?.toFloatArray()

        let rawW = CVPixelBufferGetWidth(pixelBuffer)
        let rawH = CVPixelBufferGetHeight(pixelBuffer)
        // The .left/.right family rotates the buffer 90°, so width/height swap once oriented.
        let orientedSize: CGSize
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            orientedSize = CGSize(width: rawH, height: rawW)
        default:
            orientedSize = CGSize(width: rawW, height: rawH)
        }

        return DetectedPose(
            joints: joints,
            confidences: confidences,
            timestamp: timestamp,
            sourceSize: orientedSize,
            keypoints: keypoints
        )
    }
}
