import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var selectedTab = 0
    @State private var tabBarVisible = true
    @State private var tickId = UUID()
    /// App-open streak / new-PR celebration toast (#250). Cleared after auto-dismiss.
    @State private var launchBadgeToast: Toast?

    private let resumeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var workoutSession = workoutSession

        ZStack {
            Group {
                switch selectedTab {
                case 0: FeedView()
                case 1: WorkoutView()
                case 2: XomProgressView()
                case 3: ProfileView()
                default: FeedView()
                }
            }
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                )
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedTab)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                if workoutSession.isActive && !workoutSession.isPresented {
                    WorkoutResumeBar(
                        workoutName: workoutSession.workoutName,
                        durationString: workoutSession.durationString,
                        isPaused: workoutSession.isPaused,
                        tickId: tickId,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                workoutSession.isPresented = true
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if tabBarVisible {
                    FloatingTabBar(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: workoutSession.isActive)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: workoutSession.isPresented)
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
        }
        .toast($launchBadgeToast)
        .task {
            // App-open streak / PR badge (#250).
            // Show at most one toast per launch; surface ~1s in so it
            // doesn't collide with the tab bar's mount animation.
            guard let userId = authService.currentUser?.id.uuidString.lowercased() else { return }
            let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
            guard let badge = BadgeToastService.badgeForLaunch(workouts: workouts) else { return }
            try? await Task.sleep(for: .seconds(1))
            launchBadgeToast = Toast(style: .success, message: badge.message)
        }
        .environment(\.tabBarVisible, $tabBarVisible)
    }
}

// MARK: - Tab Bar Visibility Environment Key

private struct TabBarVisibleKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibleKey.self] }
        set { self[TabBarVisibleKey.self] = newValue }
    }
}

/// Apply to any view pushed inside a NavigationStack to hide the floating tab bar.
struct HideTabBar: ViewModifier {
    @Environment(\.tabBarVisible) private var tabBarVisible

    func body(content: Content) -> some View {
        content
            .onAppear { withAnimation(.xomChill) { tabBarVisible.wrappedValue = false } }
            .onDisappear { withAnimation(.xomChill) { tabBarVisible.wrappedValue = true } }
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBar())
    }
}

// MARK: - Workout Resume Bar

/// Compact "Workout in progress" pill shown above the tab bar when a workout is active
/// but the active workout cover is dismissed. Tap to re-present the cover.
private struct WorkoutResumeBar: View {
    let workoutName: String
    let durationString: String
    let isPaused: Bool
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

                VStack(alignment: .leading, spacing: 2) {
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

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Feed"),
        ("dumbbell.fill", "Workout"),
        ("chart.line.uptrend.xyaxis", "Progress"),
        ("person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: tabs[index].icon)
                            .font(selectedTab == index ? .title3 : .body)
                            .symbolEffect(.bounce, value: selectedTab == index)

                        Text(tabs[index].label)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selectedTab == index ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .accessibilityLabel(tabs[index].label)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 12)
        .safeAreaPadding(.bottom)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.lg,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Theme.Radius.lg
            )
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                // Single 0.5pt top hairline
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        )
    }
}
