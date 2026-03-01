import Foundation
import CoreGraphics

struct PoseKeypoint: Identifiable, Codable {
    var id: UUID
    var name: String
    var x: Double // 0.0 - 1.0 normalized
    var y: Double // 0.0 - 1.0 normalized
    var confidence: Double
    
    init(id: UUID = UUID(), name: String, x: Double, y: Double, confidence: Double) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

struct FormAnalysisResult: Identifiable, Codable {
    var id: UUID
    var exerciseName: String
    var formScore: Int // 0 - 100
    var barPath: [CGPoint]
    var keypoints: [PoseKeypoint]
    var coachNotes: [String]
    var rangeOfMotion: Double // degrees
    var breakdown: FormBreakdown
    var recordedAt: Date
    var videoLocalPath: String?
    
    init(id: UUID = UUID(), exerciseName: String, formScore: Int, barPath: [CGPoint] = [],
         keypoints: [PoseKeypoint] = [], coachNotes: [String] = [], rangeOfMotion: Double = 0,
         breakdown: FormBreakdown, videoLocalPath: String? = nil) {
        self.id = id
        self.exerciseName = exerciseName
        self.formScore = formScore
        self.barPath = barPath
        self.keypoints = keypoints
        self.coachNotes = coachNotes
        self.rangeOfMotion = rangeOfMotion
        self.breakdown = breakdown
        self.recordedAt = Date()
        self.videoLocalPath = videoLocalPath
    }
    
    var scoreLabel: String {
        switch formScore {
        case 90...: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        default: return "Needs Work"
        }
    }
    
    var scoreColor: String {
        switch formScore {
        case 90...: return "green"
        case 75..<90: return "blue"
        case 60..<75: return "orange"
        default: return "red"
        }
    }
}

struct FormBreakdown: Codable {
    var backAlignment: Int // 0-100
    var depthScore: Int // 0-100
    var kneeTracking: Int // 0-100
    var barPath: Int // 0-100
    var tempo: Int // 0-100
    
    var average: Int { (backAlignment + depthScore + kneeTracking + barPath + tempo) / 5 }
    
    static func fromMockAnalysis(exerciseName: String) -> FormBreakdown {
        // Generate plausible scores for common exercises
        let isSquat = exerciseName.lowercased().contains("squat")
        let isBench = exerciseName.lowercased().contains("bench")
        return FormBreakdown(
            backAlignment: Int.random(in: 70...95),
            depthScore: isSquat ? Int.random(in: 65...90) : Int.random(in: 75...100),
            kneeTracking: isSquat ? Int.random(in: 60...90) : Int.random(in: 80...100),
            barPath: isBench ? Int.random(in: 70...95) : Int.random(in: 75...95),
            tempo: Int.random(in: 65...90)
        )
    }
}

struct VideoSession: Identifiable, Codable {
    var id: UUID
    var exerciseName: String
    var thumbnailPath: String?
    var analysisResult: FormAnalysisResult?
    var recordedAt: Date
    var durationSeconds: Double
    
    init(id: UUID = UUID(), exerciseName: String, durationSeconds: Double = 0) {
        self.id = id
        self.exerciseName = exerciseName
        self.recordedAt = Date()
        self.durationSeconds = durationSeconds
    }
}
