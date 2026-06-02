import SwiftUI
import Vision

/// Renders a detected pose as a skeleton on top of the camera preview.
/// `pose.joints` is in Vision-normalized coordinates (origin bottom-left, [0,1]),
/// so we flip Y when drawing into SwiftUI's top-left coordinate space.
struct SkeletonOverlay: View {
    let pose: DetectedPose?
    var pointRadius: CGFloat = 5
    var lineWidth: CGFloat = 3

    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard let pose else { return }
                // The preview uses `.resizeAspectFill`, which scales the camera image to
                // cover the view and crops the overflow. Replicate that exact transform so
                // joints sit on the body rather than on the un-cropped normalized rectangle.
                let project = Self.aspectFillProjector(sourceSize: pose.sourceSize, viewSize: size)

                for (a, b) in Self.bones {
                    guard let pa = pose.joints[a], let pb = pose.joints[b] else { continue }
                    var path = Path()
                    path.move(to: project(pa))
                    path.addLine(to: project(pb))
                    ctx.stroke(path, with: .color(.green.opacity(0.85)), lineWidth: lineWidth)
                }
                for (_, point) in pose.joints {
                    let p = project(point)
                    let rect = CGRect(x: p.x - pointRadius, y: p.y - pointRadius, width: pointRadius * 2, height: pointRadius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.yellow))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }

    /// Returns a closure mapping a Vision-normalized point (origin bottom-left, [0,1])
    /// into the aspect-fill-cropped view space (origin top-left).
    private static func aspectFillProjector(sourceSize: CGSize, viewSize: CGSize) -> (CGPoint) -> CGPoint {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return { CGPoint(x: $0.x * viewSize.width, y: (1 - $0.y) * viewSize.height) }
        }
        let scale = max(viewSize.width / sourceSize.width, viewSize.height / sourceSize.height)
        let displayedWidth = sourceSize.width * scale
        let displayedHeight = sourceSize.height * scale
        let offsetX = (viewSize.width - displayedWidth) / 2
        let offsetY = (viewSize.height - displayedHeight) / 2
        return { p in
            CGPoint(
                x: offsetX + p.x * displayedWidth,
                y: offsetY + (1 - p.y) * displayedHeight
            )
        }
    }
}
