import Foundation

/// Local persistence for the user's `WeeklyPlan`. Mirrors `TemplateService`'s
/// shape exactly: `@MainActor final class`, `static let shared`, a single
/// UserDefaults JSON blob, graceful `nil` on missing/corrupt data.
///
/// The plan is consumed by `TrainingNudgeService.resolvedBaseline()` to construct
/// a `GoalBaseline` when a plan exists.
@MainActor
final class WeeklyPlanService {
    static let shared = WeeklyPlanService()

    private let key = "xomfit.weeklyPlan"

    private init() {}

    // MARK: - Public

    /// The saved plan, or `nil` when never set / cleared / corrupt.
    func currentPlan() -> WeeklyPlan? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeeklyPlan.self, from: data)
    }

    func save(_ plan: WeeklyPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Test seam

    /// Clears the persisted plan. Mirrors `TrainingNudgeService.resetForTesting`.
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: "xomfit.weeklyPlan")
    }
}
