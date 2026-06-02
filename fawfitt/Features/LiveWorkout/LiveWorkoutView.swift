import SwiftUI

struct LiveWorkoutView: View {
    @StateObject private var tracker: MotionTracker
    @Environment(\.dismiss) private var dismiss
    /// Human-readable name of the exercise the user is supposed to be doing, used to
    /// show a form-match indicator against the CoreML-detected action.
    private let targetExerciseName: String
    /// Reps the user is supposed to hit. `0` = no target (count indefinitely).
    private let targetReps: Int
    /// Optional callback fired when the user ends the set with reps > 0.
    var onFinish: ((LiveWorkoutResult) -> Void)?

    /// Guards against the auto-finish and the manual "Finish set" button both firing.
    @State private var isFinishing = false

    init(
        exerciseId: String = "squat",
        targetExerciseName: String = "",
        targetReps: Int = 0,
        tracker: MotionTracker? = nil,
        onFinish: ((LiveWorkoutResult) -> Void)? = nil
    ) {
        _tracker = StateObject(wrappedValue: tracker ?? MotionTracker(exerciseId: exerciseId, targetReps: targetReps))
        self.targetExerciseName = targetExerciseName.isEmpty ? exerciseId : targetExerciseName
        self.targetReps = targetReps
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            CameraPreviewView(session: tracker.camera.captureSession)
                .ignoresSafeArea()

            SkeletonOverlay(pose: tracker.pose)
                .ignoresSafeArea()

            VStack {
                statusBar
                actionBanner
                Spacer()
                bottomBar
            }
            .padding()

            if case .denied = tracker.state {
                permissionDeniedOverlay
            }

            if isFinishing {
                completionOverlay
            }
        }
        .task { await tracker.start() }
        .onDisappear { _ = tracker.stop() }
        .onChange(of: tracker.reachedTarget) { reached in
            guard reached else { return }
            autoFinish()
        }
    }

    /// Called when the user reaches the target reps: celebrate briefly, then end the set.
    private func autoFinish() {
        guard !isFinishing else { return }
        isFinishing = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            finish()
        }
    }

    /// Stops tracking, reports the result, and dismisses. Safe to call more than once.
    private func finish() {
        let result = tracker.stop()
        if let result { onFinish?(result) }
        dismiss()
    }

    private var completionOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Set selesai!")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("\(tracker.repCount) reps")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(32)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }

    private var statusBar: some View {
        HStack {
            Button {
                _ = tracker.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            Spacer()
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5), in: Capsule())
        }
    }

    /// Shows the CoreML-detected exercise + a checkmark when it matches the target move.
    private var actionBanner: some View {
        let detected = tracker.detectedAction
        let matches = formMatches(detected: detected, target: targetExerciseName)
        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: tracker.actionClassifier.usingCoreML ? "brain.head.profile" : "wand.and.stars")
                    .foregroundStyle(.cyan)
                Text("Detected: \(detected)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if tracker.detectedActionConfidence > 0 {
                    Text("\(Int(tracker.detectedActionConfidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if matches {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5), in: Capsule())
        .padding(.top, 8)
    }

    private func formMatches(detected: String, target: String) -> Bool {
        let d = detected.lowercased()
        let t = target.lowercased()
        if d.contains("squat") && t.contains("squat") { return true }
        if d.contains("push") && t.contains("push") { return true }
        if d.contains("plank") && t.contains("plank") { return true }
        if d.contains("jack") && t.contains("jack") { return true }
        if d.contains("lunge") && t.contains("lunge") { return true }
        return false
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Text(targetReps > 0 ? "\(tracker.repCount) / \(targetReps)" : "\(tracker.repCount)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 6)
                .contentTransition(.numericText())
            Text("reps")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            if targetReps > 0 {
                ProgressView(value: Double(min(tracker.repCount, targetReps)), total: Double(targetReps))
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .frame(maxWidth: 240)
            }

            HStack(spacing: 16) {
                Button("Reset") { tracker.reset() }
                    .buttonStyle(.bordered)
                    .tint(.white)

                Button {
                    finish()
                } label: {
                    Text("Finish set")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        }
        .padding(.bottom, 24)
    }

    private var statusText: String {
        switch tracker.state {
        case .idle: return "Idle"
        case .requestingPermission: return "Requesting camera…"
        case .denied: return "Camera denied"
        case .starting: return "Starting…"
        case .searching: return "Searching for you"
        case .tracking: return "Tracking"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill").font(.system(size: 48))
            Text("Camera access denied")
                .font(.title3.weight(.semibold))
            Text("Enable camera in Settings to use rep counting, or log reps manually.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Back") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(40)
    }
}

extension MotionTracker {
    /// Mock instance for SwiftUI previews. Doesn't access the camera.
    static var preview: MotionTracker {
        MotionTracker(exerciseId: "squat")
    }
}

struct LiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        LiveWorkoutView(tracker: MotionTracker.preview)
    }
}
