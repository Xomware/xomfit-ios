import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignOutConfirm = false

    private var userEmail: String {
        authService.currentUser?.email ?? "—"
    }

    private var userInitials: String {
        let email = userEmail
        let firstChar = email.first.map { String($0).uppercased() } ?? "?"
        return firstChar
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    // Avatar + email header
                    Section {
                        HStack(spacing: Theme.paddingMedium) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                Text(userInitials)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userEmail)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Member")
                                    .font(Theme.fontCaption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Theme.cardBackground)
                    }

                    // Workout stats (from local storage)
                    Section("Stats") {
                        let workouts = WorkoutService.shared.fetchWorkouts()
                        StatRow(label: "Total Workouts", value: "\(workouts.count)")
                        StatRow(label: "Total Sets", value: "\(workouts.reduce(0) { $0 + $1.totalSets })")
                        StatRow(label: "Total Volume", value: {
                            let v = workouts.reduce(0.0) { $0 + $1.totalVolume }
                            if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
                            return "\(Int(v)) lbs"
                        }())
                    }
                    .listRowBackground(Theme.cardBackground)

                    // Sign Out
                    Section {
                        Button(role: .destructive) {
                            showSignOutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(Theme.destructive)
                        }
                        .listRowBackground(Theme.cardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be returned to the login screen.")
        }
    }
}

// MARK: - Helpers

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }
}
