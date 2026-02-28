import Foundation
import SwiftUI

@MainActor
class PRViewModel: ObservableObject {
    @Published var personalRecords: [PersonalRecord] = []
    @Published var recentPRs: [PersonalRecord] = []
    @Published var newPRNotification: PersonalRecord?
    @Published var isShowingCelebration = false
    @Published var prsByExercise: [String: [PersonalRecord]] = [:]
    @Published var prLeaderboard: [User: [PersonalRecord]] = [:]
    @Published var currentUserStats: (oneRM: Int, threeRM: Int, fiveRM: Int)?
    
    private let calculator = PRCalculator.self
    
    init() {
        loadPersonalRecords()
        loadLeaderboard()
    }
    
    // MARK: - Loading Data
    
    func loadPersonalRecords() {
        // In production, this would fetch from API/database
        personalRecords = PersonalRecord.mockPRs
        updateStats()
        groupPRsByExercise()
    }
    
    func loadLeaderboard() {
        // In production, this would fetch friends' PRs from API
        let mockUser = User.mockUser
        prLeaderboard = [mockUser: PersonalRecord.mockPRs]
    }
    
    // MARK: - PR Detection from Workout
    
    func detectNewPRsInWorkout(_ workout: Workout) {
        let detections = calculator.detectPRsInWorkout(
            workout: workout,
            existingPRs: personalRecords
        )
        
        guard !detections.isEmpty else { return }
        
        // Create PersonalRecord entries
        let newPRs = calculator.createPersonalRecords(
            from: workout,
            detections: detections
        )
        
        // Update local records
        personalRecords.append(contentsOf: newPRs)
        recentPRs = Array(personalRecords.sorted { $0.date > $1.date }.prefix(5))
        
        // Trigger celebrations for each new PR
        for pr in newPRs {
            showPRCelebration(for: pr)
        }
        
        updateStats()
        groupPRsByExercise()
    }
    
    // MARK: - Celebration Animation
    
    func showPRCelebration(for pr: PersonalRecord) {
        newPRNotification = pr
        isShowingCelebration = true
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                self.isShowingCelebration = false
            }
        }
    }
    
    // MARK: - Data Organization
    
    private func groupPRsByExercise() {
        var grouped: [String: [PersonalRecord]] = [:]
        for pr in personalRecords {
            if grouped[pr.exerciseName] == nil {
                grouped[pr.exerciseName] = []
            }
            grouped[pr.exerciseName]?.append(pr)
        }
        prsByExercise = grouped
    }
    
    private func updateStats() {
        let oneRMs = personalRecords.filter { $0.reps == 1 }.sorted { $0.weight > $1.weight }
        let threeRMs = personalRecords.filter { $0.reps == 3 }.sorted { $0.weight > $1.weight }
        let fiveRMs = personalRecords.filter { $0.reps == 5 }.sorted { $0.weight > $1.weight }
        
        currentUserStats = (
            oneRM: Int(oneRMs.first?.weight ?? 0),
            threeRM: Int(threeRMs.first?.weight ?? 0),
            fiveRM: Int(fiveRMs.first?.weight ?? 0)
        )
    }
    
    // MARK: - Leaderboard Operations
    
    func getPRsForExercise(_ exerciseName: String) -> [PersonalRecord] {
        (prsByExercise[exerciseName] ?? []).sorted { $0.date > $1.date }
    }
    
    func getTopPRForExercise(_ exerciseName: String) -> PersonalRecord? {
        (prsByExercise[exerciseName] ?? []).max { $0.weight < $1.weight }
    }
    
    func getLeaderboardForExercise(_ exerciseName: String) -> [(user: User, pr: PersonalRecord)] {
        var leaderboard: [(user: User, pr: PersonalRecord)] = []
        
        for (user, prs) in prLeaderboard {
            if let topPR = prs.filter({ $0.exerciseName == exerciseName }).max(by: { $0.weight < $1.weight }) {
                leaderboard.append((user, topPR))
            }
        }
        
        return leaderboard.sorted { $0.pr.weight > $1.pr.weight }
    }
    
    func updateLeaderboard(with friends: [User], completionHandler: @escaping () -> Void) {
        // In production, fetch PRs for all friends from API
        DispatchQueue.main.async {
            // Simulate API call
            completionHandler()
        }
    }
}
