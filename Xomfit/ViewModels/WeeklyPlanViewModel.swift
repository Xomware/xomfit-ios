import Foundation
import Observation

/// MVVM bridge between `WeeklyPlanView` and `WeeklyPlanService`. Holds the
/// editable plan state (target sessions + focus regions) and persists it.
/// The view never touches `WeeklyPlanService` or `UserDefaults` directly.
@MainActor
@Observable
final class WeeklyPlanViewModel {

    /// Session-count bounds for the stepper.
    static let minSessions = 1
    static let maxSessions = 14
    static let defaultSessions = 4

    var targetSessions: Int
    var focusRegions: [TrainingRegion]

    /// True when a plan is currently persisted (drives Clear-button visibility).
    private(set) var hasPlan: Bool

    init() {
        if let plan = WeeklyPlanService.shared.currentPlan() {
            targetSessions = plan.targetSessions
            focusRegions = plan.focusRegions
            hasPlan = true
        } else {
            targetSessions = Self.defaultSessions
            focusRegions = []
            hasPlan = false
        }
    }

    func isSelected(_ region: TrainingRegion) -> Bool {
        focusRegions.contains(region)
    }

    func toggle(_ region: TrainingRegion) {
        if let idx = focusRegions.firstIndex(of: region) {
            focusRegions.remove(at: idx)
        } else {
            focusRegions.append(region)
        }
    }

    func save() {
        let clamped = min(max(targetSessions, Self.minSessions), Self.maxSessions)
        targetSessions = clamped
        let plan = WeeklyPlan(targetSessions: clamped, focusRegions: focusRegions)
        WeeklyPlanService.shared.save(plan)
        hasPlan = true
    }

    func clearPlan() {
        WeeklyPlanService.shared.clear()
        targetSessions = Self.defaultSessions
        focusRegions = []
        hasPlan = false
    }
}
