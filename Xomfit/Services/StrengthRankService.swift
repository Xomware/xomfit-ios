import Foundation
import Supabase

// MARK: - Rows

private struct StrengthRankRow: Codable {
    let userId: String
    let exerciseId: String
    let exerciseName: String
    let tier: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case tier
    }
}

/// A lifter's rank on one lift, as published to their profile.
///
/// Carries no weights — see `user_strength_ranks` for why. Distinct from
/// `StrengthLevelService.RankedLift`, which is the locally computed version and
/// does know the numbers.
struct PublishedRank: Identifiable, Equatable {
    var id: String { exerciseId }
    let exerciseId: String
    let exerciseName: String
    let tier: StrengthTier
}

/// Publishes the signed-in lifter's strength ranks and reads anyone's.
///
/// The split matters: ranking needs bodyweight, sex and age, and two of those
/// have never left the device. So a rank is always computed by its owner, on
/// their own phone, and only the resulting tier is shared. Nobody's profile
/// ranks anybody else.
@MainActor
@Observable
final class StrengthRankService {
    static let shared = StrengthRankService()

    /// Ranks by user id, so a profile can render without refetching on every
    /// redraw. Not persisted — it is cheap to refill and stale ranks on someone
    /// else's profile are worse than a brief empty state.
    private(set) var ranksByUser: [String: [PublishedRank]] = [:]

    private init() {}

    func ranks(for userId: String) -> [PublishedRank] {
        ranksByUser[userId] ?? []
    }

    /// Ranks held by a lifter, strongest first.
    @discardableResult
    func fetchRanks(userId: String) async -> [PublishedRank] {
        guard !userId.isEmpty else { return [] }
        do {
            let rows: [StrengthRankRow] = try await supabase
                .from("user_strength_ranks")
                .select("user_id,exercise_id,exercise_name,tier")
                .eq("user_id", value: userId)
                .execute()
                .value

            let ranks = rows
                .compactMap { row -> PublishedRank? in
                    guard let tier = StrengthTier(rawValue: row.tier), tier != .unranked else { return nil }
                    return PublishedRank(
                        exerciseId: row.exerciseId,
                        exerciseName: row.exerciseName,
                        tier: tier
                    )
                }
                .sorted { lhs, rhs in
                    lhs.tier != rhs.tier ? lhs.tier > rhs.tier : lhs.exerciseName < rhs.exerciseName
                }

            ranksByUser[userId] = ranks
            return ranks
        } catch {
            print("[StrengthRankService] fetch failed: \(error)")
            return ranksByUser[userId] ?? []
        }
    }

    /// Publishes the signed-in lifter's ranks, replacing what was there.
    ///
    /// Upserts rather than delete-then-insert so a failure part-way leaves the
    /// previous ranks standing instead of wiping a profile. Rows for lifts that
    /// dropped out entirely are removed separately, and only once the upsert
    /// succeeded — a lifter's profile going blank because a write failed is a
    /// worse outcome than one stale row.
    func publish(_ lifts: [StrengthLevelService.RankedLift], userId: String) async {
        guard !userId.isEmpty else { return }

        let rows = lifts
            .filter { $0.rank.tier != .unranked }
            .map {
                StrengthRankRow(
                    userId: userId,
                    exerciseId: $0.exerciseId,
                    exerciseName: $0.exerciseName,
                    tier: $0.rank.tier.rawValue
                )
            }

        guard !rows.isEmpty else { return }

        do {
            try await supabase
                .from("user_strength_ranks")
                .upsert(rows, onConflict: "user_id,exercise_id")
                .execute()

            ranksByUser[userId] = rows.compactMap { row in
                guard let tier = StrengthTier(rawValue: row.tier) else { return nil }
                return PublishedRank(
                    exerciseId: row.exerciseId,
                    exerciseName: row.exerciseName,
                    tier: tier
                )
            }
            .sorted { $0.tier > $1.tier }
        } catch {
            print("[StrengthRankService] publish failed: \(error)")
        }
    }
}
