import CoreML
import CoreGraphics
import Foundation
import Vision

/// On-device exercise recognition.
///
/// Primary path: a Create ML **Action Classifier** (`.mlmodel`) that takes a rolling
/// window of body-pose keypoints and predicts which exercise the user is performing.
/// Drop a model named `ExerciseActionClassifier.mlmodel` into the app target and Xcode
/// compiles it to `.mlmodelc` automatically — this class loads it at runtime via the
/// generic `MLModel` API (no generated class needed, so the project still builds when
/// the model is absent).
///
/// Fallback path: when no model is bundled, a lightweight joint-geometry heuristic keeps
/// the feature usable for demos (squat / push-up / plank / jumping jack / idle).
@MainActor
final class ExerciseActionClassifier: ObservableObject {

    @Published private(set) var action: String = "—"
    @Published private(set) var confidence: Double = 0
    @Published private(set) var usingCoreML: Bool = false

    /// Number of frames the Action Classifier expects per prediction. MUST match the
    /// "prediction window" the bundled model was trained on. Apple's GuessMyExercise
    /// sample (`ExerciseClassifier.mlmodel`) uses 64; Create ML's default is 60.
    private let windowSize = 64
    private let jointCount = 18
    private let inputFeatureName = "poses"

    private var model: MLModel?
    private var window: [[Float]] = []          // each entry: 54 floats (3×18)
    private var poseWindow: [DetectedPose] = []  // mirror window for the heuristic fallback

    /// Resource names searched, in priority order. The first one found wins. Apple's
    /// WWDC sample drops `ExerciseClassifier.mlmodel`; a custom-trained model usually
    /// keeps the `ExerciseActionClassifier` name. Either ships fine.
    private static let modelCandidates = ["ExerciseActionClassifier", "ExerciseClassifier"]

    init(modelName: String? = nil) {
        let names = modelName.map { [$0] } ?? Self.modelCandidates
        loadModel(named: names)
    }

    private func loadModel(named names: [String]) {
        // Xcode compiles `.mlmodel` → `.mlmodelc` in the bundle. Try compiled first.
        for name in names {
            let candidates: [URL?] = [
                Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
                Bundle.main.url(forResource: name, withExtension: "mlmodel")
            ]
            for case let url? in candidates {
                let config = MLModelConfiguration()
                config.computeUnits = .all   // CPU + GPU + Neural Engine
                if let loaded = try? MLModel(contentsOf: url, configuration: config) {
                    model = loaded
                    usingCoreML = true
                    print("[CoreML] ExerciseActionClassifier loaded from \(url.lastPathComponent)")
                    return
                }
            }
        }
        usingCoreML = false
        print("[CoreML] No action classifier model bundled (tried \(names.joined(separator: ", "))) — using heuristic fallback")
    }

    func reset() {
        window.removeAll(keepingCapacity: true)
        poseWindow.removeAll(keepingCapacity: true)
        action = "—"
        confidence = 0
    }

    /// Feed one detected pose. Once a full window has accumulated, runs a prediction.
    func ingest(pose: DetectedPose) {
        poseWindow.append(pose)
        if poseWindow.count > windowSize { poseWindow.removeFirst(poseWindow.count - windowSize) }

        if let kp = pose.keypoints, kp.count == 3 * jointCount {
            window.append(kp)
            if window.count > windowSize { window.removeFirst(window.count - windowSize) }
        }

        if usingCoreML, window.count == windowSize {
            classifyWithCoreML()
        } else if !usingCoreML {
            classifyWithHeuristic()
        }
    }

    // MARK: - CoreML path

    private func classifyWithCoreML() {
        guard let model, let input = try? makeInput() else { return }
        guard let output = try? model.prediction(from: input) else { return }

        if let label = output.featureValue(for: "label")?.stringValue {
            action = label
            if let probs = output.featureValue(for: "labelProbabilities")?.dictionaryValue {
                // dictionaryValue is [AnyHashable: NSNumber]; pull out this label's probability.
                for (key, value) in probs where (key as? String) == label {
                    confidence = value.doubleValue
                    break
                }
            }
        }
    }

    private func makeInput() throws -> MLFeatureProvider {
        let shape = [NSNumber(value: windowSize), 3, NSNumber(value: jointCount)]
        let array = try MLMultiArray(shape: shape, dataType: .float32)
        for f in 0..<windowSize {
            let frame = window[f]
            for c in 0..<3 {
                for j in 0..<jointCount {
                    array[[NSNumber(value: f), NSNumber(value: c), NSNumber(value: j)]] =
                        NSNumber(value: frame[c * jointCount + j])
                }
            }
        }
        return try MLDictionaryFeatureProvider(
            dictionary: [inputFeatureName: MLFeatureValue(multiArray: array)]
        )
    }

    // MARK: - Heuristic fallback (no model required)

    private func classifyWithHeuristic() {
        guard let pose = poseWindow.last else { return }
        let minC: Float = 0.3

        func pt(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? { pose.point(j, minConfidence: minC) }

        let shoulder = pt(.leftShoulder) ?? pt(.rightShoulder)
        let hip = pt(.leftHip) ?? pt(.rightHip)
        let knee = pt(.leftKnee) ?? pt(.rightKnee)
        let ankle = pt(.leftAnkle) ?? pt(.rightAnkle)
        let wrist = pt(.leftWrist) ?? pt(.rightWrist)

        // Torso tilt: vertical (standing) vs horizontal (plank / push-up).
        if let s = shoulder, let h = hip {
            let dx = abs(s.x - h.x)
            let dy = abs(s.y - h.y)
            let horizontal = dx > dy * 1.2
            if horizontal {
                set("Push-Up / Plank", 0.55)
                return
            }
        }

        // Knee bend → squat depth.
        if let h = hip, let k = knee, let a = ankle,
           let kneeAngle = JointAngle.angleDegrees(a: h, b: k, c: a) {
            if kneeAngle < 130 {
                set("Squat", 0.6)
                return
            }
        }

        // Arms raised overhead → jumping jack.
        if let w = wrist, let s = shoulder, w.y > s.y {
            set("Jumping Jack", 0.5)
            return
        }

        set("Idle / Standing", 0.4)
    }

    private func set(_ label: String, _ conf: Double) {
        action = label
        confidence = conf
    }
}
