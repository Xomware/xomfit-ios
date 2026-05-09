import Foundation

/// Lightweight UserDefaults-backed profile capturing what the user told us about
/// their lifting goals. Used to seed the AI Coach system prompt with context.
///
/// Defined as part of the AI Coach groundwork slice (#252). Issue #259 may
/// replace this with a richer/Supabase-backed model — keep field names stable.
struct UserFitnessProfile: Codable, Equatable {
    var primaryGoal: String?
    var experience: String?
    var workoutsPerWeek: Int?
    var preferredSplit: String?
    var sessionLengthMin: Int?
    var completedAt: Date?

    init(
        primaryGoal: String? = nil,
        experience: String? = nil,
        workoutsPerWeek: Int? = nil,
        preferredSplit: String? = nil,
        sessionLengthMin: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.primaryGoal = primaryGoal
        self.experience = experience
        self.workoutsPerWeek = workoutsPerWeek
        self.preferredSplit = preferredSplit
        self.sessionLengthMin = sessionLengthMin
        self.completedAt = completedAt
    }

    // MARK: - Persistence

    private static let storageKey = "userFitnessProfile.v1"

    /// The currently stored profile, or an empty one if nothing is persisted.
    static var current: UserFitnessProfile {
        get { load() ?? UserFitnessProfile() }
        set { newValue.save() }
    }

    private static func load() -> UserFitnessProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(UserFitnessProfile.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - Derived

    /// True when the user has saved at least one onboarding pass.
    var isComplete: Bool { completedAt != nil }
}
