import SwiftUI

struct NotificationPreferencesView: View {
    @Environment(AuthService.self) private var authService
    @State private var prefs: NotificationPreferences?
    @State private var isLoading = true

    // Local-only toggles (#369). These gate in-process scheduling and aren't
    // synced to Supabase — they live in UserDefaults via NotificationService.
    @State private var restTimerEnabled: Bool = NotificationService.shared.restTimerLocalEnabled
    @State private var warmupEnabled: Bool = NotificationService.shared.warmupLocalEnabled
    @State private var weeklyReportEnabled: Bool = NotificationService.shared.weeklyReportEnabled

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let prefs = Binding($prefs) {
                List {
                    // In-workout local notifications (#369) — gated by
                    // UserDefaults toggles in NotificationService, not synced to DB.
                    Section {
                        localToggle(
                            "Rest Timer",
                            icon: "timer",
                            isOn: $restTimerEnabled
                        ) { NotificationService.shared.restTimerLocalEnabled = $0 }
                        localToggle(
                            "Warmup",
                            icon: "figure.cooldown",
                            isOn: $warmupEnabled
                        ) { NotificationService.shared.warmupLocalEnabled = $0 }
                    } header: {
                        XomMetricLabel("In-Workout")
                    } footer: {
                        Text("Local alerts that ping you when a rest or warmup timer completes — useful when your phone is in your pocket.")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowSeparatorTint(Theme.hairline)

                    Section {
                        prefToggle("Social", icon: "bubble.left.and.bubble.right.fill", isOn: prefs.social)
                        prefToggle("Friend Activity", icon: "figure.strengthtraining.traditional", isOn: prefs.friendActivity)
                    } header: {
                        XomMetricLabel("Social")
                    }
                    .listRowSeparatorTint(Theme.hairline)

                    Section {
                        prefToggle("PR Celebrations", icon: "trophy.fill", isOn: prefs.personalRecords)
                        prefToggle("Workout Reminders", icon: "alarm.fill", isOn: prefs.workoutReminders)
                        prefToggle("Challenges", icon: "flag.fill", isOn: prefs.challenges)
                        localToggle(
                            "Weekly Report",
                            icon: "chart.bar.doc.horizontal",
                            isOn: $weeklyReportEnabled
                        ) { NotificationService.shared.weeklyReportEnabled = $0 }
                    } header: {
                        XomMetricLabel("Activity")
                    }
                    .listRowSeparatorTint(Theme.hairline)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prefs = NotificationService.shared.preferences
                ?? NotificationPreferences.defaultPrefs(userId: userId)
            isLoading = false
        }
        .onChange(of: prefs) { _, newPrefs in
            if let newPrefs {
                NotificationService.shared.updatePreferences(newPrefs)
            }
        }
    }

    private func prefToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Spacing.lg)
                Text(label)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }

    /// Toggle bound to a local UserDefaults flag (#369). `onUpdate` writes back
    /// into NotificationService so the change persists across launches.
    private func localToggle(
        _ label: String,
        icon: String,
        isOn: Binding<Bool>,
        onUpdate: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                onUpdate(newValue)
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Spacing.lg)
                Text(label)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }
}
