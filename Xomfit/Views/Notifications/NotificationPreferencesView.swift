import SwiftUI

struct NotificationPreferencesView: View {
    @State private var prefs = NotificationService.shared.preferences

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    prefToggle("Friend Requests", icon: "person.badge.plus", isOn: $prefs.friendRequests)
                    prefToggle("Likes", icon: "heart.fill", isOn: $prefs.likes)
                    prefToggle("Comments", icon: "bubble.right.fill", isOn: $prefs.comments)
                } header: {
                    Text("Social")
                }

                Section {
                    prefToggle("Personal Records", icon: "trophy.fill", isOn: $prefs.personalRecords)
                    prefToggle("Streak Milestones", icon: "flame.fill", isOn: $prefs.streakMilestones)
                    prefToggle("Friend Workouts", icon: "figure.strengthtraining.traditional", isOn: $prefs.friendWorkouts)
                } header: {
                    Text("Activity")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: prefs.friendRequests) { _, _ in save() }
        .onChange(of: prefs.likes) { _, _ in save() }
        .onChange(of: prefs.comments) { _, _ in save() }
        .onChange(of: prefs.personalRecords) { _, _ in save() }
        .onChange(of: prefs.streakMilestones) { _, _ in save() }
        .onChange(of: prefs.friendWorkouts) { _, _ in save() }
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

    private func save() {
        NotificationService.shared.updatePreferences(prefs)
    }
}
