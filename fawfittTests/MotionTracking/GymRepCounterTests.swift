import Testing
import Foundation
@testable import fawfitt

@Suite("GymRepCounter")
struct GymRepCounterTests {

    /// Squat-style thresholds: extended (up) above 160°, flexed (down) below 110°.
    private func squatCounter(smoothingWindow: Int = 1, minSeconds: Double = 0.0) -> GymRepCounter {
        GymRepCounter(downAngle: 110, upAngle: 160, isLegExercise: false,
                      smoothingWindow: smoothingWindow, minSecondsBetweenReps: minSeconds)
    }

    private func feed(_ counter: GymRepCounter, _ angle: Double, at t: Double) {
        counter.consume(leftAngle: angle, rightAngle: angle, timestamp: t)
    }

    @Test("three clean up→down cycles produce three reps")
    func cleanThreeReps() {
        let counter = squatCounter()
        var t = 0.0
        for _ in 0..<3 {
            for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }  // extended
            for _ in 0..<5 { feed(counter, 80, at: t); t += 0.1 }   // flexed → +1
        }
        #expect(counter.repCount == 3)
    }

    @Test("oscillation around the down threshold does not double-count")
    func jitterAroundDownThresholdDoesNotDoubleCount() {
        let counter = squatCounter()
        var t = 0.0
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        for _ in 0..<5 { feed(counter, 80, at: t); t += 0.1 }       // rep 1
        // Hover near 110 without ever extending past 160 again.
        for value in [108.0, 112.0, 109.0, 111.0, 108.0, 112.0] {
            feed(counter, value, at: t); t += 0.1
        }
        #expect(counter.repCount == 1)
    }

    @Test("partial dip that never reaches the down threshold counts no reps")
    func partialDipDoesNotCount() {
        let counter = squatCounter()
        var t = 0.0
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        for _ in 0..<5 { feed(counter, 130, at: t); t += 0.1 }      // above 110, no rep
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        #expect(counter.repCount == 0)
    }

    @Test("rapid bouncing faster than the debounce window is suppressed")
    func debounceSuppressesRapidBouncing() {
        let counter = squatCounter(minSeconds: 1.0)
        var t = 0.0
        feed(counter, 170, at: t); t += 0.05
        feed(counter, 80, at: t); t += 0.05                         // rep 1
        let afterFirst = counter.repCount

        feed(counter, 170, at: t); t += 0.05
        feed(counter, 80, at: t); t += 0.05                         // <1s later → suppressed

        #expect(afterFirst == 1)
        #expect(counter.repCount == 1)
    }

    @Test("debounce allows a second rep once the window has elapsed")
    func debounceAllowsAfterWindow() {
        let counter = squatCounter(minSeconds: 0.5)
        var t = 0.0
        feed(counter, 170, at: t); t += 0.05
        feed(counter, 80, at: t); t += 0.05
        #expect(counter.repCount == 1)

        t += 1.0
        feed(counter, 170, at: t); t += 0.05
        feed(counter, 80, at: t); t += 0.05
        #expect(counter.repCount == 2)
    }

    @Test("reset clears rep count and state")
    func resetClears() {
        let counter = squatCounter()
        var t = 0.0
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        for _ in 0..<5 { feed(counter, 80, at: t); t += 0.1 }
        #expect(counter.repCount == 1)

        counter.reset()
        #expect(counter.repCount == 0)
        #expect(counter.state == .unknown)
    }

    @Test("inverted thresholds (bicep-curl style) count on flexion")
    func invertedThresholdsCount() {
        // Good-GYM bicep curl: up=60, down=160. Extend → curl is one rep.
        let counter = GymRepCounter(downAngle: 160, upAngle: 60, isLegExercise: false,
                                    smoothingWindow: 1, minSecondsBetweenReps: 0.0)
        var t = 0.0
        for _ in 0..<2 {
            feed(counter, 170, at: t); t += 0.1   // arm extended → state up
            feed(counter, 40, at: t); t += 0.1    // curled (<160) → +1
        }
        #expect(counter.repCount == 2)
    }

    @Test("leg exercises count each leg independently")
    func legExercisesCountPerSide() {
        let counter = GymRepCounter(downAngle: 110, upAngle: 160, isLegExercise: true,
                                    smoothingWindow: 1, minSecondsBetweenReps: 0.0)
        var t = 0.0
        counter.consume(leftAngle: 170, rightAngle: 170, timestamp: t); t += 0.1  // both up
        counter.consume(leftAngle: 80, rightAngle: 170, timestamp: t); t += 0.1   // left rep
        counter.consume(leftAngle: 170, rightAngle: 170, timestamp: t); t += 0.1  // both up
        counter.consume(leftAngle: 170, rightAngle: 80, timestamp: t); t += 0.1   // right rep
        #expect(counter.repCount == 2)
    }

    @Test("a missing side skips the frame")
    func missingSideSkipsFrame() {
        let counter = squatCounter()
        var t = 0.0
        // Only one side visible → no state change, no rep.
        counter.consume(leftAngle: 170, rightAngle: nil, timestamp: t); t += 0.1
        counter.consume(leftAngle: 80, rightAngle: nil, timestamp: t); t += 0.1
        #expect(counter.repCount == 0)
    }

    @Test("smoothing absorbs a single-frame spike")
    func smoothingAbsorbsSpike() {
        let counter = squatCounter(smoothingWindow: 5)
        var t = 0.0
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        feed(counter, 50, at: t); t += 0.1   // single bad sample, should be rejected
        for _ in 0..<5 { feed(counter, 170, at: t); t += 0.1 }
        #expect(counter.repCount == 0)
    }
}
