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
    @State private var restHapticsEnabled: Bool = NotificationService.shared.restHapticsEnabled
    @State private var wristHapticsEnabled: Bool = NotificationService.shared.wristHapticsEnabled
    @State private var phoneHapticsEnabled: Bool = NotificationService.shared.phoneHapticsEnabled
    @State private var trainingNudgeEnabled: Bool = NotificationService.shared.trainingNudgeEnabled

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
                        localToggle(
                            "Rest Countdown Haptics",
                            icon: "waveform.path",
                            isOn: $restHapticsEnabled
                        ) { NotificationService.shared.restHapticsEnabled = $0 }

                        // Independent rather than exclusive, so every
                        // combination is reachable — both, either, or neither.
                        if restHapticsEnabled {
                            localToggle(
                                "  Buzz my watch",
                                icon: "applewatch",
                                isOn: $wristHapticsEnabled
                            ) { NotificationService.shared.wristHapticsEnabled = $0 }
                            localToggle(
                                "  Buzz my phone",
                                icon: "iphone.radiowaves.left.and.right",
                                isOn: $phoneHapticsEnabled
                            ) { NotificationService.shared.phoneHapticsEnabled = $0 }
                        }
                    } header: {
                        XomMetricLabel("In-Workout")
                    } footer: {
                        Text("Local alerts that ping you when a rest or warmup timer completes. Haptics tick for the last five seconds of rest, then buzz for three — on your Apple Watch, your Garmin, your phone, or any combination. Most lifters turn the phone off once a watch is paired; it's in your bag, not on you.")
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
                        if prefs.workoutReminders.wrappedValue {
                            reminderSchedule(prefs)
                        }
                        prefToggle("Challenges", icon: "flag.fill", isOn: prefs.challenges)
                        localToggle(
                            "Weekly Report",
                            icon: "chart.bar.doc.horizontal",
                            isOn: $weeklyReportEnabled
                        ) { NotificationService.shared.weeklyReportEnabled = $0 }
                        localToggle(
                            "Come-Back Nudges",
                            icon: "figure.run.circle",
                            isOn: $trainingNudgeEnabled
                        ) { NotificationService.shared.trainingNudgeEnabled = $0 }
                    } header: {
                        XomMetricLabel("Activity")
                    } footer: {
                        Text("Come-back nudges ping you at 6pm when a muscle group is behind your usual week — even if you haven't opened the app.")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
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

    /// Time-of-day and day-of-week controls for the workout reminder.
    ///
    /// These preferences existed on the model since the first release and were
    /// never editable, so the reminder had no schedule to fire on even once
    /// something read them.
    @ViewBuilder
    private func reminderSchedule(_ prefs: Binding<NotificationPreferences>) -> some View {
        DatePicker(
            "Time",
            selection: reminderTimeBinding(prefs),
            displayedComponents: .hourAndMinute
        )
        .font(Theme.fontBody)
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Days")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(0..<7, id: \.self) { day in
                    dayPill(day, prefs: prefs)
                }
            }

            if prefs.reminderDays.wrappedValue.isEmpty {
                // A reminder switched on with no days selected fires never,
                // which reads as broken rather than as "off".
                Text("Pick at least one day or the reminder won't fire.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.destructive)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .listRowBackground(Theme.surface)
    }

    private func dayPill(_ day: Int, prefs: Binding<NotificationPreferences>) -> some View {
        let isOn = prefs.reminderDays.wrappedValue.contains(day)
        return Button {
            Haptics.selection()
            var days = Set(prefs.reminderDays.wrappedValue)
            if days.contains(day) { days.remove(day) } else { days.insert(day) }
            prefs.reminderDays.wrappedValue = days.sorted()
        } label: {
            Text(Self.dayInitials[day])
                .font(Theme.fontCaption.weight(.bold))
                .foregroundStyle(isOn ? .black : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated),
                    in: .rect(cornerRadius: Theme.Radius.sm)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.dayNames[day])
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Bridges the stored hour/minute pair to the `DatePicker`'s `Date`.
    /// Only the time components are ever read back out.
    private func reminderTimeBinding(_ prefs: Binding<NotificationPreferences>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = prefs.reminderHour.wrappedValue
                components.minute = prefs.reminderMinute.wrappedValue
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                prefs.reminderHour.wrappedValue = components.hour ?? 18
                prefs.reminderMinute.wrappedValue = components.minute ?? 0
            }
        )
    }

    private static let dayInitials = ["S", "M", "T", "W", "T", "F", "S"]
    private static let dayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]

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
