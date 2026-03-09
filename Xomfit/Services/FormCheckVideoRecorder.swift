import AVFoundation
import Combine
import UIKit

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording(duration: Double)
    case stopped
    case failed(String)
}

// MARK: - FormCheckVideoRecorder

/// Manages AVCaptureSession for recording short form-check clips (5-15 s).
@MainActor
final class FormCheckVideoRecorder: NSObject, ObservableObject {

    // MARK: Published state
    @Published var recordingState: RecordingState = .idle
    @Published var elapsedSeconds: Double = 0
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var recordedVideoURL: URL?
    @Published var isFrontCamera: Bool = false

    // MARK: Configuration
    static let minDuration: Double = 5
    static let maxDuration: Double = 15

    // MARK: Private
    private let session = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var durationTimer: Timer?
    private var currentVideoInput: AVCaptureDeviceInput?

    // MARK: - Setup

    func setupSession() async {
        recordingState = .preparing

        guard await requestPermissions() else {
            recordingState = .failed("Camera or microphone access denied. Please enable in Settings.")
            return
        }

        await configureSession(useFront: isFrontCamera)
    }

    private func requestPermissions() async -> Bool {
        let cameraStatus = await AVCaptureDevice.requestAccess(for: .video)
        let micStatus = await AVCaptureDevice.requestAccess(for: .audio)
        return cameraStatus && micStatus
    }

    private func configureSession(useFront: Bool) async {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Video input
        let position: AVCaptureDevice.Position = useFront ? .front : .back
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            recordingState = .failed("Could not configure camera input.")
            return
        }
        session.addInput(videoInput)
        currentVideoInput = videoInput

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie file output — enforce max duration
        movieOutput = AVCaptureMovieFileOutput()
        movieOutput.maxRecordedDuration = CMTime(seconds: Self.maxDuration, preferredTimescale: 600)
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()

        // Preview layer (must be created on main thread)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer

        // Start running
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
            await MainActor.run { [weak self] in
                self?.recordingState = .idle
            }
        }
    }

    // MARK: - Camera Flip

    func flipCamera() {
        isFrontCamera.toggle()
        Task { await configureSession(useFront: isFrontCamera) }
    }

    // MARK: - Record / Stop

    func startRecording() {
        guard recordingState == .idle else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("formcheck_\(UUID().uuidString).mov")

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        elapsedSeconds = 0
        recordingState = .recording(duration: 0)

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsedSeconds += 0.1
                self.recordingState = .recording(duration: self.elapsedSeconds)
                // Auto-stop at max
                if self.elapsedSeconds >= Self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard case .recording = recordingState else { return }
        durationTimer?.invalidate()
        durationTimer = nil
        movieOutput.stopRecording()
    }

    // MARK: - Teardown

    func stopSession() {
        durationTimer?.invalidate()
        durationTimer = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
        }
        recordingState = .idle
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension FormCheckVideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                self.recordingState = .failed(error.localizedDescription)
            } else {
                self.recordedVideoURL = outputFileURL
                self.recordingState = .stopped
            }
        }
    }
}
