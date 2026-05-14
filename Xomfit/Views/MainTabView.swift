import SwiftUI

// MARK: - MainTabView (now: MainShell)
//
// Replaces the previous 4-tab `FloatingTabBar` with a `NavigationStack`-rooted
// shell that surfaces a left-edge hamburger drawer (#372). The drawer lists
// every top-level destination (Feed, Workout, Progress, Profile, Reports,
// Tools, Settings).
//
// The type stays named `MainTabView` for binary-compat with `XomfitApp.swift`
// (and to keep the existing project file pointer stable). All "tab" semantics
// are gone — what remains is a single active destination + a custom top bar.
//
// Existing screens drop their inner `NavigationStack` wrappers and live inside
// this shell's stack so their `NavigationLink`s and `.navigationDestination`s
// keep working. Pushed views still get the system navigation bar; the root
// destination hides it and shows the shell's custom top bar instead.

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Navigation State

    @State private var destination: AppDestination = MainTabView.initialDestination()
    @State private var isDrawerOpen = false
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

    /// Default drawer width: ~78% of the screen, clamped so it doesn't grow
    /// absurd on iPad widths. iOS resolves this via GeometryReader below.
    private let drawerMaxWidth: CGFloat = 320

    private var drawerAnimation: Animation {
        reduceMotion ? .linear(duration: 0.0001) : .xomConfident
    }

    var body: some View {
        @Bindable var workoutSession = workoutSession

        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Active destination content
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    shellTopBar
                    destinationContent
                }

                // Dim overlay behind the drawer
                if isDrawerOpen {
                    Color.black
                        .opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            closeDrawer()
                        }
                        .accessibilityHidden(true)
                }

                // Drawer surface
                if isDrawerOpen {
                    GeometryReader { proxy in
                        let width = min(proxy.size.width * 0.78, drawerMaxWidth)
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
                        .frame(width: width)
                        .gesture(drawerCloseDragGesture)
                    }
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(drawerAnimation, value: isDrawerOpen)
        }
        // Workout resume bar — pinned above home indicator, visible only when a
        // session exists and its full-screen cover is dismissed.
        .safeAreaInset(edge: .bottom) {
            if workoutSession.isActive && !workoutSession.isPresented {
                WorkoutResumeBar(
                    workoutName: workoutSession.workoutName,
                    durationString: workoutSession.durationString,
                    isPaused: workoutSession.isPaused,
                    isWatchConnected: WatchSyncService.shared.isWatchAvailable,
                    tickId: tickId,
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            workoutSession.isPresented = true
                        }
                    }
                )
                .padding(.bottom, Theme.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: workoutSession.isActive)
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: workoutSession.isPresented)
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
            NotificationInboxView()
        }
        .toast($launchBadgeToast)
        .task {
            // App-open streak / PR badge (#250).
            // Show at most one toast per launch; surface ~1s in so it doesn't
            // collide with the shell's mount animation.
            guard let userId = authService.currentUser?.id.uuidString.lowercased() else { return }
            let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
            if let badge = BadgeToastService.badgeForLaunch(workouts: workouts) {
                try? await Task.sleep(for: .seconds(1))
                launchBadgeToast = Toast(style: .success, message: badge.message)
            }
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

    // MARK: - Top Bar

    private var shellTopBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                Haptics.light()
                openDrawer()
            } label: {
                XomAvatar(
                    name: drawerProfile.displayName.isEmpty ? drawerProfile.username : drawerProfile.displayName,
                    size: 36,
                    imageURL: drawerProfile.avatarURL
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Open navigation drawer")

            Text(destination.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                Haptics.light()
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if NotificationService.shared.unreadCount > 0 {
                        Circle()
                            .fill(Theme.destructive)
                            .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(NotificationService.shared.unreadCount > 0
                ? "Notifications, \(NotificationService.shared.unreadCount) unread"
                : "Notifications")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.5)
        }
    }

    // MARK: - Destination Switch

    @ViewBuilder
    private var destinationContent: some View {
        Group {
            switch destination {
            case .feed:     FeedView()
            case .workout:  WorkoutView()
            case .progress: XomProgressView()
            case .profile:  ProfileView()
            case .reports:  ReportsListView()
            case .tools:    ToolsView()
            case .settings: SettingsView()
            }
        }
        .transition(.opacity)
        .id(destination)
    }

    // MARK: - Drawer Helpers

    private func openDrawer() {
        withAnimation(drawerAnimation) {
            isDrawerOpen = true
        }
    }

    private func closeDrawer() {
        withAnimation(drawerAnimation) {
            isDrawerOpen = false
        }
    }

    private func select(destination newValue: AppDestination) {
        closeDrawer()
        // Defer the switch a hair so the close animation reads as intentional.
        if newValue != destination {
            withAnimation(.xomChill) {
                destination = newValue
            }
        }
    }

    /// Swipe-left-to-close gesture wired to the drawer surface.
    private var drawerCloseDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                // Negative horizontal translation = swipe toward the leading edge.
                if value.translation.width < -40 {
                    closeDrawer()
                }
            }
    }

    // MARK: - Drawer Profile Hydration

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
// modification. The hamburger drawer replaces the floating tab bar (#372),
// so there's nothing to actually hide — the modifier is a graceful shim.

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
                    if isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(durationString)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                            .id(tickId)
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
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .stroke(Theme.hairline, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused
            ? "Paused workout \(workoutName.isEmpty ? "Workout" : workoutName)"
            : "Resume workout \(workoutName.isEmpty ? "Workout" : workoutName)")
        .accessibilityHint("Reopens the active workout screen")
    }
}
