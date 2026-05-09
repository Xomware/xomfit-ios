import Foundation

// MARK: - WorkoutTab

/// Top-level segments on the Workout screen.
enum WorkoutTab: String, CaseIterable, Identifiable {
    case mine
    case recent
    case templates
    case friends

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mine:      return "Mine"
        case .recent:    return "Recent"
        case .templates: return "Templates"
        case .friends:   return "Friends"
        }
    }

    var icon: String {
        switch self {
        case .mine:      return "star.fill"
        case .recent:    return "clock.fill"
        case .templates: return "list.bullet.rectangle.portrait"
        case .friends:   return "person.2.fill"
        }
    }
}

// MARK: - WorkoutTabViewModel

@MainActor
@Observable
final class WorkoutTabViewModel {
    /// Persistence key for the active tab.
    private static let selectedTabKey = "xomfit_workout_selected_tab"

    // Per-tab data
    var recent: [Workout] = []
    var myTemplates: [WorkoutTemplate] = []
    var savedTemplates: [WorkoutTemplate] = []
    var builtInTemplates: [WorkoutTemplate] = []
    var friendWorkouts: [Workout] = []

    // UI state
    var selectedTab: WorkoutTab {
        didSet { UserDefaults.standard.set(selectedTab.rawValue, forKey: Self.selectedTabKey) }
    }
    var filter: WorkoutFilter = WorkoutFilter()

    var isLoading: Bool = false
    var isLoadingFriends: Bool = false
    var errorMessage: String?

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.selectedTabKey)
        self.selectedTab = stored.flatMap(WorkoutTab.init(rawValue:)) ?? .templates
    }

    // MARK: - Load

    /// Loads everything needed to populate all four tabs in parallel.
    /// Friend workouts are deferred to `loadFriends` because they fan out across users.
    func load(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        async let recentTask = WorkoutService.shared.fetchWorkouts(userId: userId)
        let allCustom = TemplateService.shared.allTemplates().filter { $0.isCustom }

        recent = await recentTask
        myTemplates = allCustom.filter { $0.category != .saved }
        savedTemplates = allCustom.filter { $0.category == .saved }
        builtInTemplates = TemplateService.shared.allTemplates().filter { !$0.isCustom }

        // Kick off friend workouts in the background so the visible tabs render immediately.
        Task { await loadFriends(currentUserId: userId) }
    }

    func loadFriends(currentUserId: String) async {
        guard !currentUserId.isEmpty else { return }
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        friendWorkouts = await WorkoutService.shared.fetchFriendsRecentWorkouts(currentUserId: currentUserId)
    }

    // MARK: - Filtered Output

    var filteredTemplatesMine: [WorkoutTemplate] {
        myTemplates.filter(filter.matches)
    }

    var filteredTemplatesSaved: [WorkoutTemplate] {
        savedTemplates.filter(filter.matches)
    }

    /// Combines built-in templates with user-saved templates for the "Templates" tab.
    var filteredTemplatesBuiltIn: [WorkoutTemplate] {
        (builtInTemplates + savedTemplates).filter(filter.matches)
    }

    var filteredRecent: [Workout] {
        recent.filter(filter.matches)
    }

    var filteredFriendWorkouts: [Workout] {
        friendWorkouts.filter(filter.matches)
    }

    /// True when the active tab has source data but no items pass the filter.
    func isEmptyAfterFilter(for tab: WorkoutTab) -> Bool {
        switch tab {
        case .mine:
            return !myTemplates.isEmpty && filteredTemplatesMine.isEmpty
        case .recent:
            return !recent.isEmpty && filteredRecent.isEmpty
        case .templates:
            return !(builtInTemplates.isEmpty && savedTemplates.isEmpty) && filteredTemplatesBuiltIn.isEmpty
        case .friends:
            return !friendWorkouts.isEmpty && filteredFriendWorkouts.isEmpty
        }
    }
}
