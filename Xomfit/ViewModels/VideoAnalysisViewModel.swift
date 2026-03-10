import Foundation
import SwiftUI

@MainActor
class VideoAnalysisViewModel: ObservableObject {
    @Published var analysisResult: FormAnalysisResult?
    @Published var sessions: [VideoSession] = []
    @Published var isRecording = false
    @Published var isAnalyzing = false
    @Published var selectedExercise = "Squat"
    @Published var showResults = false
    
    private let service = VideoAnalysisService.shared
    
    let exercises = ["Squat", "Bench Press", "Deadlift", "Overhead Press", "Row", "Pull-up"]
    
    func startAnalysis(videoURL: URL) {
        isAnalyzing = true
        service.analyzeVideo(url: videoURL, exerciseName: selectedExercise) { result in
            self.analysisResult = result
            self.isAnalyzing = false
            self.showResults = true
        }
    }
    
    func runDemoAnalysis() {
        isAnalyzing = true
        // Simulate analysis delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let breakdown = FormBreakdown.fromMockAnalysis(exerciseName: self.selectedExercise)
            let keypoints = self.service.generateMockKeypoints()
            let notes = self.service.generateCoachNotes(breakdown: breakdown, exerciseName: self.selectedExercise)
            
            self.analysisResult = FormAnalysisResult(
                exerciseName: self.selectedExercise,
                formScore: breakdown.average,
                keypoints: keypoints,
                coachNotes: notes,
                rangeOfMotion: Double.random(in: 80...130),
                breakdown: breakdown
            )
            self.sessions = self.service.sessions
            self.isAnalyzing = false
            self.showResults = true
        }
    }
    
    func loadSessions() {
        sessions = service.sessions
    }
}
