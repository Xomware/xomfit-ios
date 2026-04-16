import SwiftUI

struct NotificationPreferencesView: View {
    @Environment(AuthService.self) private var authService
    @State private var prefs: NotificationPreferences?
    @State private var isLoading = true

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
                    Section {
                        prefToggle("Social", icon: "bubble.left.and.bubble.right.fill", isOn: prefs.social)
                        prefToggle("Friend Activity", icon: "figure.strengthtraining.traditional", isOn: prefs.friendActivity)
                    } header: {
                        XomMetricLabel("Social")
                    }
                    .listRowSeparatorTint(Theme.hairline)

                    Section {
                        prefToggle("Personal Records", icon: "trophy.fill", isOn: prefs.personalRecords)
                        prefToggle("Workout Reminders", icon: "alarm.fill", isOn: prefs.workoutReminders)
                        prefToggle("Challenges", icon: "flag.fill", isOn: prefs.challenges)
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
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                Text(label)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }
}
