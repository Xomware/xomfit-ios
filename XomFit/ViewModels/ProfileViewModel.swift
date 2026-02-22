import Foundation

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User = .mock
    @Published var recentPRs: [PersonalRecord] = PersonalRecord.mockPRs
    @Published var workoutCount: Int = 247
    @Published var isLoading = false
    
    func refresh() {
        isLoading = true
        // Mock refresh
        isLoading = false
    }
}
