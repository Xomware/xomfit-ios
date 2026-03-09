import SwiftUI
import AVFoundation

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let layer = previewLayer else { return }
        layer.frame = uiView.bounds
        if layer.superlayer == nil {
            uiView.layer.addSublayer(layer)
        }
    }
}

// MARK: - FormCheckVideoView

/// Full-screen camera UI with record/stop controls and duration indicator.
/// Presented modally when the user taps "Record Form Check" on a set.
struct FormCheckVideoView: View {
    @StateObject private var recorder = FormCheckVideoRecorder()
    @StateObject private var trimmer = VideoTrimmer()
    @StateObject private var uploadService = VideoUploadService.shared

    let set: WorkoutSet
    let exerciseName: String
    var onSave: ((URL?, URL?) -> Void)?   // (localURL, remoteURL)

    @Environment(\.dismiss) private var dismiss

    @State private var showTrimSheet = false
    @State private var showUploadConfirm = false
    @State private var uploadError: String?
    @State private var showError = false

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreviewView(previewLayer: recorder.previewLayer)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                topBar
                Spacer()
                bottomControls
            }
        }
        .task { await recorder.setupSession() }
        .onDisappear { recorder.stopSession() }
        .sheet(isPresented: $showTrimSheet) {
            if let url = recorder.recordedVideoURL {
                VideoTrimSheet(trimmer: trimmer, sourceURL: url) { trimmedURL in
                    showTrimSheet = false
                    showUploadConfirm = true
                }
            }
        }
        .alert("Upload Form Check?", isPresented: $showUploadConfirm) {
            Button("Upload & Save", role: .none) { Task { await uploadAndSave() } }
            Button("Save Locally Only") {
                onSave?(recorder.recordedVideoURL, nil)
                dismiss()
            }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Share this clip with friends for form feedback, or keep it private.")
        }
        .alert("Error", isPresented: $showError, presenting: uploadError) { _ in
            Button("OK") {}
        } message: { err in
            Text(err)
        }
        .onChange(of: recorder.recordingState) { _, newState in
            if case .stopped = newState, recorder.recordedVideoURL != nil {
                Task {
                    if let url = recorder.recordedVideoURL {
                        await trimmer.load(url: url)
                        showTrimSheet = true
                    }
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Duration limits label
            Text("5–15 sec")
                .font(Theme.fontCaption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)

            Spacer()

            // Flip camera
            Button(action: { recorder.flipCamera() }) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(Theme.paddingMedium)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Theme.paddingMedium) {
            // Set info
            Text("\(exerciseName) · \(set.displaySet)")
                .font(Theme.fontCaption)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
                .cornerRadius(8)

            // Duration indicator
            if case .recording = recorder.recordingState {
                DurationArcView(elapsed: recorder.elapsedSeconds,
                                min: FormCheckVideoRecorder.minDuration,
                                max: FormCheckVideoRecorder.maxDuration)
            }

            // Record button
            recordButton
        }
        .padding(.bottom, 48)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: handleRecordTap) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 80, height: 80)

                Group {
                    if case .recording = recorder.recordingState {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                    } else if case .preparing = recorder.recordingState {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: recorder.recordingState)
            }
        }
        .disabled(recorder.recordingState == .preparing)
    }

    private func handleRecordTap() {
        switch recorder.recordingState {
        case .idle, .stopped:
            recorder.startRecording()
        case .recording:
            recorder.stopRecording()
        default: break
        }
    }

    // MARK: - Upload

    private func uploadAndSave() async {
        guard let localURL = trimmer.trimmedURL ?? recorder.recordedVideoURL else { return }
        do {
            let remoteURL = try await uploadService.upload(
                localURL: localURL,
                userId: "current-user",   // replace with SessionManager.shared.userId
                setId: set.id
            )
            onSave?(localURL, remoteURL)
            dismiss()
        } catch {
            uploadError = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Duration Arc Indicator

struct DurationArcView: View {
    let elapsed: Double
    let min: Double
    let max: Double

    private var progress: Double { Swift.min(elapsed / max, 1.0) }
    private var isMinReached: Bool { elapsed >= min }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 4)
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(isMinReached ? Theme.accent : Color.orange,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            Text(String(format: "%.0f\"", elapsed))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Trim Sheet

struct VideoTrimSheet: View {
    @ObservedObject var trimmer: VideoTrimmer
    let sourceURL: URL
    var onDone: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.paddingLarge) {
                    // Preview player
                    VideoPlayerView(url: trimmer.trimmedURL ?? sourceURL)
                        .frame(maxHeight: 260)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal)

                    Text("Trim your clip")
                        .font(Theme.fontHeadline)
                        .foregroundColor(.white)

                    Text("Drag the handles to keep the best \(Int(FormCheckVideoRecorder.minDuration))–\(Int(FormCheckVideoRecorder.maxDuration)) second rep.")
                        .font(Theme.fontCaption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.paddingLarge)

                    GeometryReader { geo in
                        TrimmerScrubberView(trimmer: trimmer, frameWidth: geo.size.width)
                    }
                    .frame(height: 120)

                    Spacer()
                }
                .padding(.top, Theme.paddingLarge)

                if trimmer.isTrimming {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView("Trimming…")
                        .tint(Theme.accent)
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Trim Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Use Clip") {
                        Task {
                            if let trimmed = try? await trimmer.trim(sourceURL: sourceURL) {
                                onDone(trimmed)
                            }
                        }
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.semibold)
                    .disabled(trimmer.isTrimming)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    FormCheckVideoView(
        set: WorkoutSet.mockSets[0],
        exerciseName: "Back Squat"
    )
}
