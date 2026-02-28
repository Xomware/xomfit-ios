import Foundation
import CoreLocation

// MARK: - Gym
struct Gym: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var logoUrl: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude
        case logoUrl = "logo_url"
    }
}

// MARK: - Gym Check-in
struct GymCheckIn: Identifiable, Codable {
    let id: UUID
    var userId: String
    var gymId: UUID
    var gymName: String?         // denormalized for display
    var gymAddress: String?
    var checkedInAt: Date
    var checkedOutAt: Date?      // nil = currently active
    var note: String?
    var isPublic: Bool
    
    // Joined from profiles
    var userDisplayName: String?
    var userAvatarUrl: String?
    var userUsername: String?
    
    var isActive: Bool { checkedOutAt == nil }
    
    var duration: TimeInterval? {
        guard let out = checkedOutAt else {
            return Date().timeIntervalSince(checkedInAt)
        }
        return out.timeIntervalSince(checkedInAt)
    }
    
    var formattedDuration: String {
        guard let dur = duration else { return "" }
        let mins = Int(dur / 60)
        if mins < 60 {
            return "\(mins)m"
        }
        let hrs = mins / 60
        let rem = mins % 60
        return rem == 0 ? "\(hrs)h" : "\(hrs)h \(rem)m"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gymId = "gym_id"
        case gymName = "gym_name"
        case gymAddress = "gym_address"
        case checkedInAt = "checked_in_at"
        case checkedOutAt = "checked_out_at"
        case note
        case isPublic = "is_public"
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case userUsername = "user_username"
    }
}

// MARK: - Mock Data
extension Gym {
    static let mockGyms = [
        Gym(id: UUID(), name: "Equinox Midtown", address: "123 W 50th St, New York, NY",
            latitude: 40.7614, longitude: -73.9776),
        Gym(id: UUID(), name: "Planet Fitness", address: "456 Broadway, New York, NY",
            latitude: 40.7484, longitude: -73.9856),
        Gym(id: UUID(), name: "CrossFit NYC", address: "789 8th Ave, New York, NY",
            latitude: 40.7544, longitude: -73.9931),
    ]
}

extension GymCheckIn {
    static func mockFriendCheckIns(gymId: UUID) -> [GymCheckIn] {
        let friends = [
            ("Alex M.", "alexm", "💪"),
            ("Sarah K.", "sarahk", "🏋️"),
            ("Mike T.", "miket", "🔥"),
        ]
        return friends.enumerated().map { idx, friend in
            GymCheckIn(
                id: UUID(),
                userId: "friend-\(idx)",
                gymId: gymId,
                gymName: "Equinox Midtown",
                gymAddress: "123 W 50th St",
                checkedInAt: Date().addingTimeInterval(-Double.random(in: 900...5400)),
                checkedOutAt: nil,
                note: nil,
                isPublic: true,
                userDisplayName: friend.0,
                userAvatarUrl: nil,
                userUsername: friend.1
            )
        }
    }
}
