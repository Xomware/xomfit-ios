import SwiftUI

// MARK: - MainTabView
//
// A real `TabView` shell. This replaced a left-edge hamburger drawer (#372) —
// a pattern borrowed from Android that cost the app every affordance iOS users
// read as native: no tab bar, no large titles collapsing on scroll, no
// scroll-edge material, no interactive back-swipe. The drawer also sat under
// `.toolbar(.hidden, for: .navigationBar)` with a hand-rolled HStack standing
// in for a navigation bar.
//
// Four destinations earn tabs (Feed, Workout, Progress, Profile). The rest —
// Stretches, Stats, Settings — are reached through the leading avatar, which
// presents `AppDrawer` as a sheet.
//
// Each tab root owns its own `NavigationStack` and `.navigationTitle`; the
// shared avatar + notification bell come from `rootChrome`.

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @Environment(GeneratorPreseed.self) private var generatorPreseed
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Navigation State

    @State private var destination: AppDestination = MainTabView.initialDestination()
    /// Presents the "more destinations" sheet (formerly the slide-in drawer).
    @State private var isDrawerOpen = false
    /// A destination without a tab of its own (Stretches / Stats / Settings),
    /// presented over the shell.
    @State private var secondaryDestination: AppDestination?
    @State private var tickId = UUID()

    /// Pulls an optional initial destination from `XOMFIT_INITIAL_DESTINATION`
    /// (Debug-only). Used by agent UI verification (#372) to land directly on a
    /// non-Feed destination without scripting taps. Falls back to `.feed`.
    private static func initialDestination() -> AppDestination {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["XOMFIT_INITIAL_DESTINATION"]
        if let raw, let value = AppDestination(rawValue: raw) {
            return value
        }
        #endif
        return .feed
    }

    /// App-open streak / new-PR celebration toast (#250). Cleared after auto-dismiss.
    @State private var launchBadgeToast: Toast?

    /// The muscle surfaced by the once-per-day training nudge (#P2). Set when the
    /// nudge toast is shown; consumed on toast tap to pre-seed the generator. nil
    /// when the current toast is a badge (so tapping a badge does nothing extra).
    @State private var nudgeMuscle: MuscleGroup?

    /// Sheets owned by the shell top bar (notifications bell).
    @State private var showNotifications = false

    /// Local copy of the signed-in user's profile, used to render the drawer
    /// header without re-fetching every time the drawer opens. Lazily hydrated
    /// from `ProfileService` after first render.
    @State private var drawerProfile: DrawerProfile = .empty

    /// Theme override from Settings (#312). Empty string = follow system.
    @AppStorage("colorScheme") private var preferredColorSchemeRaw: String = ""

    /// Maps the stored value to a `ColorScheme?`. nil => follow system.
    private var resolvedColorScheme: ColorScheme? {
        switch preferredColorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private let resumeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Observable mirrors of the Now Playing capture services. Used by the resume bar to
    /// show a live track count while the active-workout cover is dismissed. Reading these
    /// here subscribes the shell to capture-state changes via the `@Observable` macro.
    @State private var spotifyCapture = SpotifyNowPlayingService.shared
    @State private var appleMusicCapture = NowPlayingService.shared

    /// Destinations that get a tab. Everything else routes through the
    /// secondary sheet/cover.
    private static let tabbedDestinations: Set<AppDestination> = [.feed, .workout, .progress, .profile]

    var body: some View {
        @Bindable var workoutSession = workoutSession

        shell
        // Destinations that aren't frequent enough to earn a tab. Reached from
        // the avatar in the leading toolbar slot — a sheet rather than the old
        // slide-in drawer, which layered over a tab bar is the worst of both
        // patterns.
        .sheet(isPresented: $isDrawerOpen) {
            AppDrawer(
                displayName: drawerProfile.displayName,
                username: drawerProfile.username,
                avatarURL: drawerProfile.avatarURL,
                activeDestination: destination,
                onSelect: { selected in
                    select(destination: selected)
                },
                onSignOut: {
                    closeDrawer()
                    Task { await authService.signOut() }
                },
                onClose: { closeDrawer() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Secondary destinations render over the tab shell rather than as tabs.
        .fullScreenCover(item: $secondaryDestination) { dest in
            NavigationStack {
                secondaryContent(dest)
                    .navigationTitle(dest.title)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { secondaryDestination = nil }
                        }
                    }
            }
        }
        .onReceive(resumeTimer) { _ in
            if workoutSession.isActive && !workoutSession.isPresented {
                tickId = UUID()
            }
        }
        .fullScreenCover(isPresented: $workoutSession.isPresented) {
            ActiveWorkoutView()
                .environment(authService)
                .environment(workoutSession)
                // #288: prevent accidental swipe-dismiss leaving the cover stuck
                // in a half-dismissed state (only the workout header bar visible).
                // The user must explicitly Discard or Finish to leave the workout.
                .interactiveDismissDisabled(workoutSession.isActive)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationInboxView(
                currentUserId: authService.currentUser?.id.uuidString.lowercased(),
                onStartSuggestion: { muscle in
                    Haptics.light()
                    generatorPreseed.pending = muscle
                    select(destination: .workout)
                }
            )
        }
        .toast($launchBadgeToast) {
            // Toast tap: only the training nudge has an action. Badge toasts
            // leave `nudgeMuscle` nil, so tapping them just dismisses.
            guard let muscle = nudgeMuscle else { return }
            nudgeMuscle = nil
            Haptics.light()
            generatorPreseed.pending = muscle
            select(destination: .workout)
        }
        .task {
            // App-open streak / PR badge (#250) — streak/PR always wins the launch.
            // Show at most one toast per launch; surface ~1s in so it doesn't
            // collide with the shell's mount animation.
            guard let userId = authService.currentUser?.id.uuidString.lowercased() else { return }
            let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
            // Queue the come-back notification up front — the badge branch below
            // returns early, and the nudge shouldn't depend on which toast won.
            NotificationService.shared.refreshTrainingNudge(workouts: workouts)

            if let badge = BadgeToastService.badgeForLaunch(workouts: workouts) {
                nudgeMuscle = nil
                try? await Task.sleep(for: .seconds(1))
                launchBadgeToast = Toast(style: .success, message: badge.message)
                return
            }
            // No badge → evaluate the once-per-day training nudge (#P2).
            if let nudge = TrainingNudgeService.nudgeForLaunch(workouts: workouts) {
                nudgeMuscle = nudge.muscle
                try? await Task.sleep(for: .seconds(1))
                launchBadgeToast = Toast(
                    style: .info,
                    message: "\u{1F3CB}\u{FE0F} Light on \(nudge.muscle.displayName) this week — generate a quick session?"
                )
            }
        }
        // Come-back nudge. Scheduled on launch and re-evaluated every time the
        // app backgrounds, because the decision depends on this week's logged
        // sets — a pending nudge that was true an hour ago may not be now.
        // Backgrounding is the moment that matters: it's the last chance to get
        // an accurate notification queued before the user stops opening the app,
        // which is exactly the case this nudge exists for.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            refreshTrainingNudgeSchedule()
        }
        .task(id: authService.currentUser?.id) {
            await hydrateDrawerProfile()
        }
        #if DEBUG
        .task {
            // Agent UI verification (#372): when XOMFIT_DRAWER_OPEN=1, force the
            // drawer open shortly after launch so screenshots can capture it
            // without needing scripted taps. Compiled out of Release builds.
            if ProcessInfo.processInfo.environment["XOMFIT_DRAWER_OPEN"] == "1" {
                try? await Task.sleep(for: .seconds(1))
                openDrawer()
            }
        }
        #endif
        .preferredColorScheme(resolvedColorScheme)
    }

    /// The tab shell plus the workout resume bar, when one is running.
    ///
    /// The bar is only attached while a workout is actually active: returning
    /// an empty view from the accessory builder still reserves the slot, which
    /// left a blank capsule floating above the tab bar.
    ///
    /// `.tabViewBottomAccessory` is the platform's mini-player slot (iOS 26+).
    /// Below that it doesn't exist, so the bar rides a `.safeAreaInset` instead
    /// and supplies its own glass/material background — the accessory slot
    /// provides that itself, so `resumeAccessory` stays bare inside it.
    @ViewBuilder
    private var shell: some View {
        if workoutSession.isActive && !workoutSession.isPresented {
            if #available(iOS 26.0, *) {
                tabs.tabViewBottomAccessory { resumeAccessory }
            } else {
                tabs.safeAreaInset(edge: .bottom) {
                    resumeAccessory
                        .xomGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } else {
            tabs
        }
    }

    /// The four tabbed destinations. Each owns its own `NavigationStack` so
    /// pushes stay scoped to their tab.
    private var tabs: some View {
        TabView(selection: $destination) {
            Tab("Feed", systemImage: "house.fill", value: AppDestination.feed) {
                NavigationStack { FeedView().rootChrome(self) }
            }
            Tab("Workout", systemImage: "dumbbell.fill", value: AppDestination.workout) {
                NavigationStack { WorkoutView().rootChrome(self) }
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppDestination.progress) {
                NavigationStack { XomProgressView().rootChrome(self) }
            }
            Tab("Profile", systemImage: "person.fill", value: AppDestination.profile) {
                NavigationStack { ProfileView().rootChrome(self) }
            }
        }
        // The tab bar gets out of the way while reading a feed or a long
        // workout list, and comes back the moment you scroll up. iOS 26+ only;
        // a no-op below, where the tab bar simply stays put.
        .xomTabBarMinimizeOnScroll()
        // Selection colour follows the brand, not the system default blue.
        .tint(Theme.accent)
    }

    /// Workout resume bar. This is the platform's mini-player slot — the same
    /// one Music uses for now-playing — so it docks above the tab bar and
    /// expands with it. It previously rode a `.safeAreaInset`, which would now
    /// sit on top of the tab bar rather than above it.
    private var resumeAccessory: some View {
        WorkoutResumeBar(
            workoutName: workoutSession.workoutName,
            durationString: workoutSession.durationString,
            isPaused: workoutSession.isPaused,
            isWatchConnected: WatchSyncService.shared.isWatchAvailable,
            tickId: tickId,
            // Live-updating via `@Observable` on the singletons (Spotify capture
            // polish). When the workout is active and tracks have been captured,
            // the resume bar surfaces a subtle "💿 N tracks" label.
            capturedTrackCount: spotifyCapture.capturedCount + appleMusicCapture.capturedCount,
            onTap: {
                workoutSession.isPresented = true
            }
        )
    }

    // MARK: - Root Toolbar
    //
    // The hand-rolled `shellTopBar` this replaces was a plain HStack sitting
    // under `.toolbar(.hidden, for: .navigationBar)`. It could not do large
    // titles, scroll-edge material, or title collapse — three things that read
    // as "native iOS" before a user can articulate why.

    /// Leading avatar → secondary destinations. Trailing bell → notifications.
    /// Applied to every tab root so the chrome is identical across them.
    @ToolbarContentBuilder
    fileprivate var rootToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Haptics.light()
                openDrawer()
            } label: {
                XomAvatar(
                    name: drawerProfile.displayName.isEmpty ? drawerProfile.username : drawerProfile.displayName,
                    size: 30,
                    imageURL: drawerProfile.avatarURL
                )
            }
            .accessibilityLabel("More destinations and account")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.light()
                showNotifications = true
            } label: {
                Image(systemName: "bell")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .overlay(alignment: .topTrailing) {
                        if NotificationService.shared.unreadCount > 0 {
                            Circle()
                                .fill(Theme.destructive)
                                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                                .offset(x: 3, y: -3)
                        }
                    }
            }
            .accessibilityLabel(NotificationService.shared.unreadCount > 0
                ? "Notifications, \(NotificationService.shared.unreadCount) unread"
                : "Notifications")
        }
    }

    /// Content for a destination that doesn't warrant a tab.
    @ViewBuilder
    fileprivate func secondaryContent(_ dest: AppDestination) -> some View {
        switch dest {
        case .stretches: StretchesView()
        case .stats:     StatsView()
        case .settings:  SettingsView()
        default:         EmptyView()
        }
    }


    // MARK: - Drawer Helpers

    fileprivate func openDrawer() {
        isDrawerOpen = true
    }

    private func closeDrawer() {
        isDrawerOpen = false
    }

    /// Routes a destination pick to either a tab switch or the secondary
    /// presentation, depending on whether it earned a tab.
    private func select(destination newValue: AppDestination) {
        closeDrawer()
        if Self.tabbedDestinations.contains(newValue) {
            secondaryDestination = nil
            destination = newValue
        } else {
            secondaryDestination = newValue
        }
    }

    // MARK: - Drawer Profile Hydration


    /// Re-evaluates and re-queues the "light on legs" come-back notification.
    private func refreshTrainingNudgeSchedule() {
        guard let userId = authService.currentUser?.id.uuidString.lowercased() else {
            NotificationService.shared.cancelTrainingNudge()
            return
        }
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
        NotificationService.shared.refreshTrainingNudge(workouts: workouts)
    }

    private func hydrateDrawerProfile() async {
        guard let userId = authService.currentUser?.id.uuidString.lowercased() else { return }
        // Seed from the auth user metadata so the avatar+name show instantly
        // before the network call resolves. The Supabase `User.userMetadata`
        // dictionary is keyed by JSON strings.
        let meta = authService.currentUser?.userMetadata ?? [:]
        let initialDisplay = stringValue(meta["display_name"]) ?? stringValue(meta["full_name"]) ?? ""
        let initialUsername = stringValue(meta["username"]) ?? ""
        if drawerProfile.displayName.isEmpty {
            drawerProfile = DrawerProfile(
                displayName: initialDisplay,
                username: initialUsername,
                avatarURL: nil
            )
        }

        do {
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)
            drawerProfile = DrawerProfile(
                displayName: profile.displayName,
                username: profile.username,
                avatarURL: profile.avatarURL.flatMap(URL.init(string:))
            )
        } catch {
            // Non-fatal — drawer still renders with metadata-seeded values or
            // initials fallback inside XomAvatar.
        }
    }

    private func stringValue(_ anyJSON: Any?) -> String? {
        guard let anyJSON else { return nil }
        // Supabase `AnyJSON` exposes `.stringValue` in newer SDKs, but to avoid
        // importing the type here we use Mirror reflection. Fall back to a
        // raw string if the value is already a String.
        if let s = anyJSON as? String { return s.isEmpty ? nil : s }
        let mirror = Mirror(reflecting: anyJSON)
        if let child = mirror.children.first(where: { $0.label == "string" }),
           let s = child.value as? String {
            return s.isEmpty ? nil : s
        }
        // Last-ditch: bridge through description for `.string("...")` cases.
        let desc = String(describing: anyJSON)
        if desc.hasPrefix("string("), let start = desc.firstIndex(of: "\""), let end = desc.lastIndex(of: "\""), start < end {
            let value = String(desc[desc.index(after: start)..<end])
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

// MARK: - Root Chrome

private extension View {
    /// Applies the shell's shared toolbar to a tab root.
    ///
    /// Each root screen keeps its own `.navigationTitle`, so titles stay where
    /// they belong; this only adds the avatar + bell that used to live in the
    /// hand-rolled top bar.
    func rootChrome(_ shell: MainTabView) -> some View {
        toolbar { shell.rootToolbar }
    }
}

// MARK: - Drawer Profile

private struct DrawerProfile: Equatable {
    var displayName: String
    var username: String
    var avatarURL: URL?

    static let empty = DrawerProfile(displayName: "", username: "", avatarURL: nil)
}

// MARK: - Tab Bar Visibility Environment Key (legacy)
//
// Kept as a no-op so existing `.hideTabBar()` call sites compile without
// modification. The system tab bar handles its own hiding on push, so
// there's nothing to do here — the modifier is a graceful shim.

private struct TabBarVisibleKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibleKey.self] }
        set { self[TabBarVisibleKey.self] = newValue }
    }
}

/// No-op modifier kept for source compatibility with screens that previously
/// hid the floating tab bar on push. The drawer replaces the tab bar entirely
/// (#372); this exists so we don't have to touch ~15 call sites in this PR.
struct HideTabBar: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBar())
    }
}

// MARK: - Workout Resume Bar

/// Compact "Workout in progress" pill shown above the home indicator when a
/// workout is active but the active workout cover is dismissed. Tap to
/// re-present the cover.
private struct WorkoutResumeBar: View {
    let workoutName: String
    let durationString: String
    let isPaused: Bool
    /// True when a watch is paired AND the watch companion app is installed.
    /// Renders an `applewatch` glyph in subtle accent so the user knows the
    /// "Done Set" button on their watch is live (#256 follow-up).
    let isWatchConnected: Bool
    /// Drives re-render of the duration string every second. Owner updates this.
    let tickId: UUID
    /// Live track count from `SpotifyNowPlayingService` + `NowPlayingService`. Rendered
    /// as a subtle disc label when > 0 (Spotify capture polish).
    let capturedTrackCount: Int
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            onTap()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: isPaused ? "pause.fill" : "dumbbell.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                    Text(workoutName.isEmpty ? "Workout" : workoutName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: Theme.Spacing.xs) {
                        if isPaused {
                            Text("Paused")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(durationString)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.xomSnappy, value: durationString)
                                .id(tickId)
                        }
                        if capturedTrackCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "opticaldisc.fill")
                                    .font(.caption2)
                                Text("\(capturedTrackCount) track\(capturedTrackCount == 1 ? "" : "s")")
                                    .font(.caption.weight(.medium).monospacedDigit())
                            }
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("\(capturedTrackCount) track\(capturedTrackCount == 1 ? "" : "s") captured")
                        }
                    }
                }

                Spacer(minLength: 0)

                if isWatchConnected {
                    Image(systemName: "applewatch")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent.opacity(0.85))
                        .accessibilityLabel("Apple Watch connected")
                }

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused
            ? "Paused workout \(workoutName.isEmpty ? "Workout" : workoutName)"
            : "Resume workout \(workoutName.isEmpty ? "Workout" : workoutName)")
        .accessibilityHint("Reopens the active workout screen")
    }
}
