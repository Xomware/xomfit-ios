import SwiftUI
import CoreLocation

@MainActor
final class GymCheckInViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var activeCheckIn: GymCheckIn?
    @Published var nearbyGyms: [Gym] = []
    @Published var friendCheckIns: [GymCheckIn] = []
    @Published var recentCheckIns: [GymCheckIn] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCheckInSheet = false
    @Published var showingCheckOutConfirm = false
    @Published var selectedGym: Gym?
    @Published var checkInNote = ""
    @Published var checkInIsPublic = true
    @Published var isCheckingIn = false
    @Published var isCheckingOut = false
    @Published var checkOutSuccessMessage: String?
    
    private let service = GymCheckInService.shared
    
    // MARK: - Load
    
    func load(userId: String, userLocation: CLLocation?) async {
        isLoading = true
        defer { isLoading = false }
        
        await service.loadActiveCheckIn(userId: userId)
        await service.loadHistory(userId: userId)
        
        if let location = userLocation {
            await service.loadNearbyGyms(location: location)
        }
        
        syncFromService()
        
        if let active = activeCheckIn {
            await service.loadFriendCheckIns(gymId: active.gymId, userId: userId)
            syncFromService()
        }
    }
    
    func refreshNearby(userLocation: CLLocation) async {
        await service.loadNearbyGyms(location: userLocation)
        syncFromService()
    }
    
    // MARK: - Check In
    
    func startCheckIn(gym: Gym) {
        selectedGym = gym
        checkInNote = ""
        checkInIsPublic = true
        showingCheckInSheet = true
    }
    
    func confirmCheckIn(userId: String) async {
        guard let gym = selectedGym else { return }
        isCheckingIn = true
        defer { isCheckingIn = false }
        
        do {
            try await service.checkIn(
                userId: userId,
                gym: gym,
                note: checkInNote.isEmpty ? nil : checkInNote,
                isPublic: checkInIsPublic
            )
            syncFromService()
            showingCheckInSheet = false
            
            // Load friends at this gym
            await service.loadFriendCheckIns(gymId: gym.id, userId: userId)
            syncFromService()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Check Out
    
    func checkOut() async {
        isCheckingOut = true
        defer { isCheckingOut = false }
        
        let gymName = activeCheckIn?.gymName ?? "gym"
        let duration = activeCheckIn?.formattedDuration ?? ""
        
        do {
            try await service.checkOut()
            syncFromService()
            checkOutSuccessMessage = "Checked out of \(gymName) after \(duration) 💪"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    
    private func syncFromService() {
        activeCheckIn = service.activeCheckIn
        nearbyGyms = service.nearbyGyms
        friendCheckIns = service.friendCheckIns
        recentCheckIns = service.recentCheckIns
    }
    
    func isWithinRange(of gym: Gym, userLocation: CLLocation) -> Bool {
        service.isWithinRange(of: gym, userLocation: userLocation)
    }
    
    func distanceLabel(to gym: Gym, from userLocation: CLLocation) -> String {
        service.formattedDistance(to: gym, from: userLocation)
    }
    
    var totalWorkoutsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return recentCheckIns.filter {
            calendar.isDate($0.checkedInAt, equalTo: now, toGranularity: .month)
        }.count
    }
}
