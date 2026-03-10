import Foundation
import Combine

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var trophies: [Trophy] = []
    @Published var selectedScope: LeaderboardScope = .friends
    @Published var selectedMetric: LeaderboardMetric = .weeklyVolume
    @Published var selectedTimeframe: LeaderboardTimeframe = .weekly
    @Published var isLoading = false
    @Published var userRank: Int?
    
    private let service = LeaderboardService.shared
    
    func load() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let entries = self.service.leaderboard(
                scope: self.selectedScope,
                metric: self.selectedMetric,
                timeframe: self.selectedTimeframe
            )
            let trophies = self.service.trophies()
            let userRank = entries.first(where: { $0.userId == "current_user" })?.rank
            
            DispatchQueue.main.async {
                self.entries = entries
                self.trophies = trophies
                self.userRank = userRank
                self.isLoading = false
            }
        }
    }
}
