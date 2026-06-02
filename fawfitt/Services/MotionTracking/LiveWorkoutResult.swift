import Foundation

/// Boundary type the live-workout flow emits when a set finishes.
/// Kept local to MotionTracking so VisionAgent never edits the Domain layer.
/// HealthyAgent is responsible for mapping this into a Domain `WorkoutSessionSummary`.
struct LiveWorkoutResult: Sendable, Equatable {
    let exerciseId: String
    let repCount: Int
    let startedAt: Date
    let endedAt: Date

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}
