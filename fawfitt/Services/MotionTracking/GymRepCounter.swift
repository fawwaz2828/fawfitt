import Foundation

/// Generic angle-based rep counter ported from Good-GYM's `ExerciseCounter`
/// (https://github.com/yo-WASSUP/Good-GYM).
///
/// One rep is registered on the `up → down` transition of the angle stream:
/// the angle must first rise above `upAngle` (the "extended" pose), then fall
/// below `downAngle` (the "flexed" pose). For ordinary moves the left/right
/// angles are averaged and median-smoothed before thresholding; for leg moves
/// each leg is tracked independently so alternating reps both count. A time
/// debounce (`minSecondsBetweenReps`) suppresses physically implausible reps.
///
/// Some moves invert the thresholds (`upAngle < downAngle`, e.g. bicep curl,
/// pull-up, crunch) — the exact comparison logic from Good-GYM is preserved so
/// those configs behave identically.
final class GymRepCounter: RepCounting {
    private(set) var repCount: Int = 0
    private(set) var state: RepCounterState = .unknown

    let downAngle: Double
    let upAngle: Double
    let isLegExercise: Bool
    let minSecondsBetweenReps: Double

    private var smoother: AngleSmoother
    private var lastRepTimestamp: TimeInterval = -.infinity
    private var legStages: (left: RepCounterState, right: RepCounterState) = (.unknown, .unknown)

    init(
        downAngle: Double,
        upAngle: Double,
        isLegExercise: Bool = false,
        smoothingWindow: Int = 5,
        minSecondsBetweenReps: Double = 0.5
    ) {
        self.downAngle = downAngle
        self.upAngle = upAngle
        self.isLegExercise = isLegExercise
        self.minSecondsBetweenReps = minSecondsBetweenReps
        self.smoother = AngleSmoother(windowSize: smoothingWindow)
    }

    func consume(leftAngle: Double?, rightAngle: Double?, timestamp: TimeInterval) {
        // Good-GYM requires both sides this frame; a missing side skips the frame.
        guard let left = leftAngle, let right = rightAngle else { return }

        if isLegExercise {
            consumeLeg(left: left, right: right, timestamp: timestamp)
        } else {
            let average = (left + right) / 2
            let smoothed = smoother.append(average)
            step(angle: smoothed, timestamp: timestamp)
        }
    }

    private func step(angle: Double, timestamp: TimeInterval) {
        if angle > upAngle {
            state = .up
        } else if angle < downAngle, state == .up, timingAllows(timestamp) {
            state = .down
            repCount += 1
            lastRepTimestamp = timestamp
        }
        // Between the thresholds the previous state is held (hysteresis).
    }

    private func consumeLeg(left: Double, right: Double, timestamp: TimeInterval) {
        guard timingAllows(timestamp) else { return }

        if left > upAngle {
            legStages.left = .up
        } else if left < downAngle, legStages.left == .up {
            repCount += 1
            lastRepTimestamp = timestamp
            legStages.left = .down
        }

        if right > upAngle {
            legStages.right = .up
        } else if right < downAngle, legStages.right == .up {
            repCount += 1
            lastRepTimestamp = timestamp
            legStages.right = .down
        }

        state = (legStages.left == .up || legStages.right == .up) ? .up : .down
    }

    private func timingAllows(_ timestamp: TimeInterval) -> Bool {
        timestamp - lastRepTimestamp >= minSecondsBetweenReps
    }

    func reset() {
        repCount = 0
        state = .unknown
        smoother.reset()
        lastRepTimestamp = -.infinity
        legStages = (.unknown, .unknown)
    }
}
