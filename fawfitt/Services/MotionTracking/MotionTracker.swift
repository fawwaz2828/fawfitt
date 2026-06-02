import AVFoundation
import Combine
import CoreGraphics
import Foundation
import Vision

enum MotionTrackingState: Equatable {
    case idle
    case requestingPermission
    case denied
    case starting
    case searching          // running but no person detected yet
    case tracking           // person detected, counting reps
    case error(String)
}

/// Glues camera capture + pose detection + rep counting into one observable.
/// Views observe published properties and never touch capture/Vision directly.
@MainActor
final class MotionTracker: ObservableObject {

    @Published private(set) var state: MotionTrackingState = .idle
    @Published private(set) var repCount: Int = 0
    @Published private(set) var pose: DetectedPose?
    @Published private(set) var lastAngle: Double?
    /// Exercise the CoreML classifier thinks the user is doing right now.
    @Published private(set) var detectedAction: String = "—"
    @Published private(set) var detectedActionConfidence: Double = 0
    /// Flips to `true` once `repCount` reaches `targetReps` (when a target is set).
    /// The view observes this to auto-finish the set.
    @Published private(set) var reachedTarget: Bool = false

    /// Number of reps the user is supposed to do. `0` means "no target" (count indefinitely).
    let targetReps: Int
    let exerciseId: String
    /// Angle/threshold config for this exercise, or `nil` for moves we don't count
    /// (plank, lunge, jumping jacks…). When `nil` the camera + overlay still run.
    let definition: ExerciseDefinition?
    let counter: RepCounting
    let camera: CameraSessionController
    let detector: PoseDetector
    let actionClassifier: ExerciseActionClassifier
    private let minPoseConfidence: Float = 0.4
    private let targetFps: Double = 15
    private var lastFrameProcessedAt: TimeInterval = 0
    private var startedAt: Date?

    init(
        exerciseId: String = "squat",
        targetReps: Int = 0,
        counter: RepCounting? = nil,
        camera: CameraSessionController = CameraSessionController(),
        detector: PoseDetector = PoseDetector(),
        actionClassifier: ExerciseActionClassifier? = nil
    ) {
        self.exerciseId = exerciseId
        self.targetReps = targetReps
        let definition = ExerciseDefinition.lookup(exerciseId)
        self.definition = definition
        if let counter {
            self.counter = counter
        } else if let definition {
            self.counter = definition.makeCounter()
        } else {
            self.counter = GymRepCounter(downAngle: 110, upAngle: 160)
        }
        self.camera = camera
        self.detector = detector
        self.actionClassifier = actionClassifier ?? ExerciseActionClassifier()
        self.camera.onFrame = { [weak self] pixelBuffer, orientation, timestamp in
            self?.processFrame(pixelBuffer: pixelBuffer, orientation: orientation, timestamp: timestamp)
        }
    }

    func start() async {
        guard case .idle = state else { return }
        state = .requestingPermission

        switch CameraSessionController.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let granted = await CameraSessionController.requestAccess()
            guard granted else { state = .denied; return }
        case .denied, .restricted:
            state = .denied
            return
        }

        do {
            state = .starting
            try camera.configure()
            camera.start()
            startedAt = Date()
            counter.reset()
            actionClassifier.reset()
            repCount = 0
            reachedTarget = false
            detectedAction = "—"
            detectedActionConfidence = 0
            state = .searching
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stop() -> LiveWorkoutResult? {
        camera.stop()
        let started = startedAt ?? Date()
        let result = LiveWorkoutResult(
            exerciseId: exerciseId,
            repCount: counter.repCount,
            startedAt: started,
            endedAt: Date()
        )
        state = .idle
        startedAt = nil
        return result.repCount > 0 ? result : nil
    }

    func reset() {
        counter.reset()
        repCount = 0
        reachedTarget = false
        lastAngle = nil
    }

    // MARK: - Frame pipeline (called on camera's videoQueue)

    nonisolated private func processFrame(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, timestamp: TimeInterval) {
        // Throttle to target fps so Vision never falls behind capture.
        Task { @MainActor in
            let minInterval = 1.0 / targetFps
            if timestamp - lastFrameProcessedAt < minInterval { return }
            lastFrameProcessedAt = timestamp
            await detect(pixelBuffer: pixelBuffer, orientation: orientation, timestamp: timestamp)
        }
    }

    private func detect(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, timestamp: TimeInterval) async {
        let detector = self.detector
        let detected: DetectedPose?
        do {
            detected = try await Task.detached(priority: .userInitiated) {
                try detector.detect(in: pixelBuffer, orientation: orientation, timestamp: timestamp)
            }.value
        } catch {
            return
        }

        guard let pose = detected else {
            self.pose = nil
            if case .tracking = state { state = .searching }
            return
        }

        self.pose = pose
        state = .tracking

        // CoreML exercise recognition: feed each pose into the rolling window.
        actionClassifier.ingest(pose: pose)
        detectedAction = actionClassifier.action
        detectedActionConfidence = actionClassifier.confidence

        // Feed the per-exercise joint angles (both sides) into the rep counter.
        guard let definition else { return }
        let left = jointAngle(from: pose, triple: definition.left)
        let right = jointAngle(from: pose, triple: definition.right)
        if let left, let right {
            lastAngle = (left + right) / 2
        } else {
            lastAngle = left ?? right
        }
        counter.consume(leftAngle: left, rightAngle: right, timestamp: timestamp)
        repCount = counter.repCount
        if targetReps > 0, repCount >= targetReps {
            reachedTarget = true
        }
    }

    private func jointAngle(from pose: DetectedPose, triple: ExerciseDefinition.Triple) -> Double? {
        guard let a = pose.point(triple.0, minConfidence: minPoseConfidence),
              let b = pose.point(triple.1, minConfidence: minPoseConfidence),
              let c = pose.point(triple.2, minConfidence: minPoseConfidence) else {
            return nil
        }
        return JointAngle.angleDegrees(a: a, b: b, c: c)
    }
}
