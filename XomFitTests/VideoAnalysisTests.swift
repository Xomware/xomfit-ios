import XCTest
@testable import XomFit

final class VideoAnalysisTests: XCTestCase {
    var service: VideoAnalysisService!
    
    override func setUp() {
        super.setUp()
        service = VideoAnalysisService.shared
    }
    
    func testGenerateMockKeypointsCount() {
        let keypoints = service.generateMockKeypoints()
        XCTAssertEqual(keypoints.count, 13)
    }
    
    func testAllKeypointsHaveValidCoordinates() {
        let keypoints = service.generateMockKeypoints()
        for kp in keypoints {
            XCTAssertGreaterThanOrEqual(kp.x, 0)
            XCTAssertLessThanOrEqual(kp.x, 1.0)
            XCTAssertGreaterThanOrEqual(kp.y, 0)
            XCTAssertLessThanOrEqual(kp.y, 1.0)
        }
    }
    
    func testKeypointConfidenceInRange() {
        let keypoints = service.generateMockKeypoints()
        for kp in keypoints {
            XCTAssertGreaterThan(kp.confidence, 0)
            XCTAssertLessThanOrEqual(kp.confidence, 1.0)
        }
    }
    
    func testFormBreakdownAverage() {
        let breakdown = FormBreakdown(backAlignment: 80, depthScore: 90, kneeTracking: 70, barPath: 85, tempo: 75)
        XCTAssertEqual(breakdown.average, 80)
    }
    
    func testFormScoreLabel() {
        let excellent = FormAnalysisResult(exerciseName: "Squat", formScore: 92, breakdown: FormBreakdown(backAlignment: 90, depthScore: 90, kneeTracking: 95, barPath: 92, tempo: 90))
        XCTAssertEqual(excellent.scoreLabel, "Excellent")
        
        let needsWork = FormAnalysisResult(exerciseName: "Squat", formScore: 50, breakdown: FormBreakdown(backAlignment: 50, depthScore: 50, kneeTracking: 50, barPath: 50, tempo: 50))
        XCTAssertEqual(needsWork.scoreLabel, "Needs Work")
    }
    
    func testCoachNotesGeneratedForLowScores() {
        let breakdown = FormBreakdown(backAlignment: 60, depthScore: 60, kneeTracking: 60, barPath: 60, tempo: 60)
        let notes = service.generateCoachNotes(breakdown: breakdown, exerciseName: "Squat")
        XCTAssertGreaterThan(notes.count, 0)
    }
    
    func testCoachNotesPositiveForHighScores() {
        let breakdown = FormBreakdown(backAlignment: 95, depthScore: 95, kneeTracking: 95, barPath: 95, tempo: 95)
        let notes = service.generateCoachNotes(breakdown: breakdown, exerciseName: "Bench Press")
        XCTAssertTrue(notes.contains { $0.contains("Great form") })
    }
    
    func testFormAnalysisResultDate() {
        let result = FormAnalysisResult(exerciseName: "Deadlift", formScore: 85, breakdown: FormBreakdown(backAlignment: 85, depthScore: 85, kneeTracking: 85, barPath: 85, tempo: 85))
        XCTAssertLessThanOrEqual(result.recordedAt, Date())
    }
    
    func testVideoSessionCreation() {
        let session = VideoSession(exerciseName: "Bench Press", durationSeconds: 10.0)
        XCTAssertEqual(session.exerciseName, "Bench Press")
        XCTAssertEqual(session.durationSeconds, 10.0)
    }
}
