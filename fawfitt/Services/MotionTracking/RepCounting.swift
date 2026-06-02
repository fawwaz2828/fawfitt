import Foundation
import Vision

enum RepCounterState: Equatable, Sendable {
    case unknown
    case up
    case down
}

/// A rep counter driven by left/right joint angles. Modeled on the Good-GYM
/// project (https://github.com/yo-WASSUP/Good-GYM): every supported exercise is
/// described by a pair of joint-angle thresholds, and reps are detected on the
/// "extended → flexed" transition of the (smoothed) average angle.
protocol RepCounting: AnyObject {
    var repCount: Int { get }
    var state: RepCounterState { get }
    /// Feed one frame's left- and right-side angles (degrees). `nil` means that
    /// side wasn't confidently visible this frame.
    func consume(leftAngle: Double?, rightAngle: Double?, timestamp: TimeInterval)
    func reset()
}

/// Per-exercise configuration ported from Good-GYM's `data/exercises.json`.
///
/// `down`/`up` are the angle thresholds that bracket one rep, and `left`/`right`
/// name the joint triple whose vertex angle is measured on each side of the body.
/// For most moves a rep is counted when the smoothed average angle crosses from
/// above `up` down through `down`; some moves (curl, pull-up, crunch) deliberately
/// invert the thresholds (`up < down`), which the same state machine handles.
struct ExerciseDefinition {
    typealias Joint = VNHumanBodyPoseObservation.JointName
    typealias Triple = (Joint, Joint, Joint)

    let id: String
    let left: Triple
    let right: Triple
    let downAngle: Double
    let upAngle: Double
    /// Leg moves (raises) are counted independently per leg, so alternating reps
    /// each increment the count instead of requiring both sides together.
    let isLegExercise: Bool

    func makeCounter(minSecondsBetweenReps: Double = 0.5, smoothingWindow: Int = 5) -> GymRepCounter {
        GymRepCounter(
            downAngle: downAngle,
            upAngle: upAngle,
            isLegExercise: isLegExercise,
            smoothingWindow: smoothingWindow,
            minSecondsBetweenReps: minSecondsBetweenReps
        )
    }

    // COCO-17 joint indices used by Good-GYM, mapped to Vision joint names.
    private static let all: [ExerciseDefinition] = [
        ExerciseDefinition(id: "squat",
                           left: (.leftHip, .leftKnee, .leftAnkle),
                           right: (.rightHip, .rightKnee, .rightAnkle),
                           downAngle: 110, upAngle: 160, isLegExercise: false),
        ExerciseDefinition(id: "pushup",
                           left: (.leftShoulder, .leftElbow, .leftWrist),
                           right: (.rightShoulder, .rightElbow, .rightWrist),
                           downAngle: 130, upAngle: 160, isLegExercise: false),
        ExerciseDefinition(id: "situp",
                           left: (.leftShoulder, .leftHip, .leftAnkle),
                           right: (.rightShoulder, .rightHip, .rightAnkle),
                           downAngle: 145, upAngle: 160, isLegExercise: false),
        ExerciseDefinition(id: "bicep_curl",
                           left: (.leftShoulder, .leftElbow, .leftWrist),
                           right: (.rightShoulder, .rightElbow, .rightWrist),
                           downAngle: 160, upAngle: 60, isLegExercise: false),
        ExerciseDefinition(id: "lateral_raise",
                           left: (.leftHip, .leftShoulder, .leftElbow),
                           right: (.rightHip, .rightShoulder, .rightElbow),
                           downAngle: 30, upAngle: 80, isLegExercise: false),
        ExerciseDefinition(id: "overhead_press",
                           left: (.leftHip, .leftShoulder, .leftElbow),
                           right: (.rightHip, .rightShoulder, .rightElbow),
                           downAngle: 100, upAngle: 150, isLegExercise: false),
        ExerciseDefinition(id: "leg_raise",
                           left: (.leftShoulder, .leftHip, .leftAnkle),
                           right: (.rightShoulder, .rightHip, .rightAnkle),
                           downAngle: 130, upAngle: 160, isLegExercise: true),
        ExerciseDefinition(id: "knee_raise",
                           left: (.leftHip, .leftKnee, .leftAnkle),
                           right: (.rightHip, .rightKnee, .rightAnkle),
                           downAngle: 110, upAngle: 160, isLegExercise: true),
        ExerciseDefinition(id: "knee_press",
                           left: (.leftHip, .leftKnee, .leftAnkle),
                           right: (.rightHip, .rightKnee, .rightAnkle),
                           downAngle: 110, upAngle: 160, isLegExercise: true),
        ExerciseDefinition(id: "crunch",
                           left: (.leftShoulder, .leftHip, .leftAnkle),
                           right: (.rightShoulder, .rightHip, .rightAnkle),
                           downAngle: 170, upAngle: 150, isLegExercise: false),
        ExerciseDefinition(id: "pullup",
                           left: (.leftShoulder, .leftElbow, .leftWrist),
                           right: (.rightShoulder, .rightElbow, .rightWrist),
                           downAngle: 140, upAngle: 70, isLegExercise: false)
    ]

    private static let byID: [String: ExerciseDefinition] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Aliases for the exercise slugs `MotionTracker`/`ContentView` may pass in.
    private static let aliases: [String: String] = [
        "push_up": "pushup", "push-up": "pushup",
        "sit_up": "situp", "sit-up": "situp",
        "curl": "bicep_curl", "bicep": "bicep_curl", "biceps_curl": "bicep_curl",
        "shoulder_press": "overhead_press", "press": "overhead_press",
        "lateral": "lateral_raise",
        "pull_up": "pullup", "pull-up": "pullup"
    ]

    /// Returns the definition for an exercise slug, or `nil` if it isn't a
    /// counted move (e.g. plank, lunge, jumping jacks) — those still get the
    /// camera and skeleton overlay but no automatic rep counting.
    static func lookup(_ exerciseId: String) -> ExerciseDefinition? {
        let key = exerciseId.lowercased()
        if let direct = byID[key] { return direct }
        if let aliased = aliases[key], let def = byID[aliased] { return def }
        return nil
    }
}
