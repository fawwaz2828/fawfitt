import CoreGraphics
import Foundation

/// Pure helpers for computing joint angles from 2D body points.
/// Kept free of Vision / AVFoundation so the rep-counting pipeline is
/// fully unit-testable from synthetic data.
enum JointAngle {

    /// Angle in degrees at vertex `b` formed by the rays `b→a` and `b→c`.
    /// Returns a value in `[0, 180]`. Returns `nil` if either ray has
    /// zero length (degenerate input).
    static func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double? {
        let v1 = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let v2 = CGPoint(x: c.x - b.x, y: c.y - b.y)

        let m1 = (v1.x * v1.x + v1.y * v1.y).squareRoot()
        let m2 = (v2.x * v2.x + v2.y * v2.y).squareRoot()
        guard m1 > 0, m2 > 0 else { return nil }

        let dot = Double(v1.x * v2.x + v1.y * v2.y)
        let cosTheta = max(-1.0, min(1.0, dot / Double(m1 * m2)))
        return acos(cosTheta) * 180.0 / .pi
    }
}
