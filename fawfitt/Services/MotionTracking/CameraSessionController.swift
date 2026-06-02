import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

enum CameraAuthorization {
    case authorized
    case denied
    case notDetermined
    case restricted
}

/// Owns an `AVCaptureSession` with a front-camera video-data output.
/// Frames are forwarded on a dedicated background queue via `onFrame`.
final class CameraSessionController: NSObject {

    /// Called on `videoQueue` for every emitted frame. The closure must be
    /// fast — heavy work (Vision) should be dispatched off this queue.
    var onFrame: ((CVPixelBuffer, CGImagePropertyOrientation, TimeInterval) -> Void)?

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "fawfitt.camera.video", qos: .userInitiated)
    private(set) var isRunning: Bool = false

    var captureSession: AVCaptureSession { session }

    static func authorizationStatus() -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Builds the capture graph. Throws if the front camera is unavailable
    /// or inputs/outputs can't be wired up.
    func configure() throws {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw NSError(domain: "CameraSessionController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Front camera unavailable"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "CameraSessionController", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
        }
        session.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else {
            throw NSError(domain: "CameraSessionController", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }

    func start() {
        guard !session.isRunning else { return }
        // AVCaptureSession.startRunning is blocking — push to background.
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
        isRunning = true
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
        isRunning = false
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        // Front camera, portrait preview, mirrored → leftMirrored gives Vision
        // an upright image with mirroring respected.
        onFrame?(pixelBuffer, .leftMirrored, timestamp)
    }
}
