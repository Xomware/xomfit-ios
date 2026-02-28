import Foundation
import CoreLocation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.xomware.xomfit", category: "GymCheckIn")

// How close a user needs to be to a gym to check in (meters)
private let kCheckInRadiusMeters: CLLocationDistance = 300

@MainActor
final class GymCheckInService: ObservableObject {
    static let shared = GymCheckInService()
    
    // MARK: - Published State
    @Published var nearbyGyms: [Gym] = []
    @Published var activeCheckIn: GymCheckIn?
    @Published var friendCheckIns: [GymCheckIn] = []
    @Published var recentCheckIns: [GymCheckIn] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Nearby Gyms
    
    /// Find gyms within the check-in radius of the user's location
    func loadNearbyGyms(location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Call Supabase RPC: nearby_gyms(lat, lng, radius_meters)
            let gyms: [Gym] = try await supabase
                .rpc("nearby_gyms", params: [
                    "lat": location.coordinate.latitude,
                    "lng": location.coordinate.longitude,
                    "radius_meters": kCheckInRadiusMeters
                ])
                .execute()
                .value
            
            nearbyGyms = gyms
            logger.info("Loaded \(gyms.count) nearby gyms")
        } catch {
            logger.warning("Supabase nearby_gyms failed, using mock: \(error)")
            nearbyGyms = Gym.mockGyms
        }
    }
    
    // MARK: - Check In
    
    /// Check in to a gym
    func checkIn(userId: String, gym: Gym, note: String? = nil, isPublic: Bool = true) async throws {
        // Can't double check-in
        if activeCheckIn != nil {
            throw NSError(domain: "GymCheckIn", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "You're already checked in. Check out first."])
        }
        
        let checkIn = GymCheckIn(
            id: UUID(),
            userId: userId,
            gymId: gym.id,
            gymName: gym.name,
            gymAddress: gym.address,
            checkedInAt: Date(),
            checkedOutAt: nil,
            note: note,
            isPublic: isPublic
        )
        
        do {
            try await supabase
                .from("gym_checkins")
                .insert(checkIn)
                .execute()
            
            activeCheckIn = checkIn
            logger.info("Checked in to \(gym.name)")
        } catch {
            logger.error("Failed to check in: \(error)")
            throw error
        }
    }
    
    // MARK: - Check Out
    
    /// End the current check-in session
    func checkOut() async throws {
        guard let current = activeCheckIn else { return }
        
        do {
            try await supabase
                .from("gym_checkins")
                .update(["checked_out_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: current.id.uuidString)
                .execute()
            
            // Update local state
            var finished = current
            finished = GymCheckIn(
                id: current.id,
                userId: current.userId,
                gymId: current.gymId,
                gymName: current.gymName,
                gymAddress: current.gymAddress,
                checkedInAt: current.checkedInAt,
                checkedOutAt: Date(),
                note: current.note,
                isPublic: current.isPublic
            )
            
            // Prepend to recent
            recentCheckIns.insert(finished, at: 0)
            activeCheckIn = nil
            
            logger.info("Checked out from \(current.gymName ?? "gym") after \(finished.formattedDuration)")
        } catch {
            logger.error("Failed to check out: \(error)")
            throw error
        }
    }
    
    // MARK: - Friend Activity
    
    /// Load current check-ins at a specific gym (from friends)
    func loadFriendCheckIns(gymId: UUID, userId: String) async {
        do {
            let checkIns: [GymCheckIn] = try await supabase
                .from("gym_checkins")
                .select("""
                    id, user_id, gym_id, gym_name, checked_in_at, checked_out_at,
                    note, is_public, user_display_name, user_avatar_url, user_username
                """)
                .eq("gym_id", value: gymId.uuidString)
                .is("checked_out_at", value: nil)          // Only active
                .neq("user_id", value: userId)             // Exclude self
                .eq("is_public", value: true)              // Only public
                .order("checked_in_at", ascending: false)
                .execute()
                .value
            
            friendCheckIns = checkIns
            logger.info("Loaded \(checkIns.count) friend check-ins at gym \(gymId)")
        } catch {
            logger.warning("Failed to load friend check-ins, using mock: \(error)")
            friendCheckIns = GymCheckIn.mockFriendCheckIns(gymId: gymId)
        }
    }
    
    // MARK: - History
    
    /// Load the user's check-in history
    func loadHistory(userId: String, limit: Int = 20) async {
        do {
            let history: [GymCheckIn] = try await supabase
                .from("gym_checkins")
                .select()
                .eq("user_id", value: userId)
                .order("checked_in_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            recentCheckIns = history.filter { !$0.isActive }
            
            // Restore active check-in if app was relaunched mid-session
            if let active = history.first(where: { $0.isActive }) {
                activeCheckIn = active
            }
        } catch {
            logger.error("Failed to load check-in history: \(error)")
        }
    }
    
    // MARK: - Resume Active
    
    /// Load active check-in on app launch (if user forgot to check out)
    func loadActiveCheckIn(userId: String) async {
        do {
            let active: [GymCheckIn] = try await supabase
                .from("gym_checkins")
                .select()
                .eq("user_id", value: userId)
                .is("checked_out_at", value: nil)
                .limit(1)
                .execute()
                .value
            
            activeCheckIn = active.first
        } catch {
            logger.error("Failed to load active check-in: \(error)")
        }
    }
    
    // MARK: - Distance helpers
    
    func isWithinRange(of gym: Gym, userLocation: CLLocation) -> Bool {
        let gymLocation = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
        return userLocation.distance(from: gymLocation) <= kCheckInRadiusMeters
    }
    
    func distance(to gym: Gym, from userLocation: CLLocation) -> CLLocationDistance {
        let gymLocation = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
        return userLocation.distance(from: gymLocation)
    }
    
    func formattedDistance(to gym: Gym, from userLocation: CLLocation) -> String {
        let d = distance(to: gym, from: userLocation)
        if d < 1000 {
            return "\(Int(d))m away"
        }
        return String(format: "%.1fkm away", d / 1000)
    }
}
