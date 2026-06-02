import CoreGraphics
import XCTest
@testable import fawfitt

final class JointAngleTests: XCTestCase {

    func testStraightLineIs180() {
        let angle = JointAngle.angleDegrees(
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 1, y: 0),
            c: CGPoint(x: 2, y: 0)
        )
        XCTAssertNotNil(angle)
        XCTAssertEqual(angle!, 180, accuracy: 1e-6)
    }

    func testRightAngleIs90() {
        let angle = JointAngle.angleDegrees(
            a: CGPoint(x: 0, y: 1),
            b: CGPoint(x: 0, y: 0),
            c: CGPoint(x: 1, y: 0)
        )
        XCTAssertNotNil(angle)
        XCTAssertEqual(angle!, 90, accuracy: 1e-6)
    }

    func testDegenerateReturnsNil() {
        let angle = JointAngle.angleDegrees(
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 0, y: 0),
            c: CGPoint(x: 1, y: 0)
        )
        XCTAssertNil(angle)
    }

    func testGymCounterIntegratesWithAngleStream() {
        let counter = GymRepCounter(
            downAngle: 95,
            upAngle: 160,
            isLegExercise: false,
            smoothingWindow: 1,
            minSecondsBetweenReps: 0.1
        )
        // Extended (170) → flexed (90) is one rep; two flex cycles → two reps.
        let sequence: [(Double, Double)] = [
            (170, 0.0), (90, 0.5), (170, 1.0),
            (90, 1.5), (170, 2.0)
        ]
        for (angle, t) in sequence {
            counter.consume(leftAngle: angle, rightAngle: angle, timestamp: t)
        }
        XCTAssertEqual(counter.repCount, 2)
    }
}
