import Foundation

@MainActor
@Observable
final class LeaderboardViewModel {
    var entries: [LeaderboardEntry] = []
    var isLoading = false
    var errorMessage: String?

    var selectedMetric: LeaderboardMetric = .weeklyVolume
    var selectedTimeframe: LeaderboardTimeframe = .weekly
    var selectedScope: LeaderboardScope = .friends
    var selectedMuscleGroup: MuscleGroup?

    func loadLeaderboard(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            entries = try await LeaderboardService.shared.fetchLeaderboard(
                metric: selectedMetric,
                timeframe: selectedTimeframe,
                scope: selectedScope,
                userId: userId,
                muscleGroupFilter: selectedMuscleGroup
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// The current user's entry, if they're on the leaderboard.
    func currentUserEntry(userId: String) -> LeaderboardEntry? {
        entries.first(where: { $0.userId == userId })
    }
}
