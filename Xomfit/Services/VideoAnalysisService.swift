import Foundation
import AVFoundation
import Vision
import CoreGraphics

@MainActor
class VideoAnalysisService: ObservableObject {
    static let shared = VideoAnalysisService()
    
    @Published var sessions: [VideoSession] = []
    @Published var isAnalyzing = false
    
    private let sessionsKey = "xomfit_video_sessions"
    
    init() { load() }
    
    // MARK: - Analyze video (using Vision framework)
    func analyzeVideo(url: URL, exerciseName: String, completion: @escaping (FormAnalysisResult) -> Void) {
        isAnalyzing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Perform body pose detection on key frames
            let keypoints = self.detectPoseKeypoints(from: url)
            let barPath = self.estimateBarPath(keypoints: keypoints)
            let rangeOfMotion = self.calculateRangeOfMotion(keypoints: keypoints, exercise: exerciseName)
            let breakdown = FormBreakdown.fromMockAnalysis(exerciseName: exerciseName)
            let formScore = breakdown.average
            let notes = self.generateCoachNotes(breakdown: breakdown, exerciseName: exerciseName)
            
            let result = FormAnalysisResult(
                exerciseName: exerciseName,
                formScore: formScore,
                barPath: barPath,
                keypoints: keypoints,
                coachNotes: notes,
                rangeOfMotion: rangeOfMotion,
                breakdown: breakdown,
                videoLocalPath: url.path
            )
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.saveSession(VideoSession(exerciseName: exerciseName, durationSeconds: 5.0))
                completion(result)
            }
        }
    }
    
    // MARK: - Vision Body Pose Detection
    private func detectPoseKeypoints(from videoURL: URL) -> [PoseKeypoint] {
        // In production: use VNDetectHumanBodyPoseRequest on video frames
        // For now, generate anatomically plausible keypoints
        return generateMockKeypoints()
    }
    
    func generateMockKeypoints() -> [PoseKeypoint] {
        [
            PoseKeypoint(name: "nose", x: 0.50, y: 0.10, confidence: 0.95),
            PoseKeypoint(name: "leftShoulder", x: 0.42, y: 0.25, confidence: 0.92),
            PoseKeypoint(name: "rightShoulder", x: 0.58, y: 0.25, confidence: 0.93),
            PoseKeypoint(name: "leftElbow", x: 0.35, y: 0.42, confidence: 0.88),
            PoseKeypoint(name: "rightElbow", x: 0.65, y: 0.42, confidence: 0.89),
            PoseKeypoint(name: "leftWrist", x: 0.30, y: 0.55, confidence: 0.85),
            PoseKeypoint(name: "rightWrist", x: 0.70, y: 0.55, confidence: 0.84),
            PoseKeypoint(name: "leftHip", x: 0.44, y: 0.55, confidence: 0.91),
            PoseKeypoint(name: "rightHip", x: 0.56, y: 0.55, confidence: 0.90),
            PoseKeypoint(name: "leftKnee", x: 0.43, y: 0.70, confidence: 0.87),
            PoseKeypoint(name: "rightKnee", x: 0.57, y: 0.70, confidence: 0.86),
            PoseKeypoint(name: "leftAnkle", x: 0.44, y: 0.88, confidence: 0.89),
            PoseKeypoint(name: "rightAnkle", x: 0.56, y: 0.88, confidence: 0.90)
        ]
    }
    
    // MARK: - Bar Path Estimation
    private func estimateBarPath(keypoints: [PoseKeypoint]) -> [CGPoint] {
        // Estimate from wrist keypoints across frames
        let wrists = keypoints.filter { $0.name.contains("Wrist") }
        guard !wrists.isEmpty else { return [] }
        
        // Simulate bar path: slight J-curve for bench press
        return (0..<10).map { i in
            let progress = Double(i) / 9.0
            let x = 0.50 + sin(progress * .pi) * 0.05
            let y = 0.20 + progress * 0.35
            return CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Range of Motion
    private func calculateRangeOfMotion(keypoints: [PoseKeypoint], exercise: String) -> Double {
        // Calculate hip angle for squat, elbow angle for bench
        let hip = keypoints.first { $0.name == "leftHip" }
        let knee = keypoints.first { $0.name == "leftKnee" }
        let ankle = keypoints.first { $0.name == "leftAnkle" }
        
        guard let h = hip, let k = knee, let a = ankle else {
            return Double.random(in: 80...120)
        }
        
        // Simple angle calculation using dot product
        let v1x = h.x - k.x; let v1y = h.y - k.y
        let v2x = a.x - k.x; let v2y = a.y - k.y
        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        let cosAngle = dot / max(mag1 * mag2, 0.001)
        let angle = acos(max(-1, min(1, cosAngle))) * 180 / .pi
        return angle
    }
    
    // MARK: - Coach Notes
    func generateCoachNotes(breakdown: FormBreakdown, exerciseName: String) -> [String] {
        var notes: [String] = []
        
        if breakdown.backAlignment < 75 {
            notes.append("⚠️ Keep your back neutral throughout the movement — avoid rounding.")
        }
        if breakdown.depthScore < 70 {
            notes.append("📐 Try to hit full depth — aim for hip crease below parallel.")
        }
        if breakdown.kneeTracking < 75 {
            notes.append("🦵 Drive knees out over toes to avoid caving.")
        }
        if breakdown.barPath < 75 {
            notes.append("📊 Bar path deviation detected — focus on a straight vertical path.")
        }
        if breakdown.tempo < 70 {
            notes.append("⏱️ Slow down the eccentric phase — 2-3 seconds down.")
        }
        
        if notes.isEmpty {
            notes.append("✅ Great form! Keep it up.")
        }
        
        return notes
    }
    
    // MARK: - Persistence
    func saveSession(_ session: VideoSession) {
        sessions.insert(session, at: 0)
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([VideoSession].self, from: data) {
            sessions = decoded
        }
    }
}
