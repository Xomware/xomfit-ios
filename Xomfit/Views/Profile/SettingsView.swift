import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignOutConfirm = false

    /// Anthropic API key override (per-user). v1: stored via @AppStorage —
    /// not secure. TODO: migrate to Keychain.
    @AppStorage("aiCoach.anthropicAPIKey") private var anthropicAPIKey: String = ""

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Short summary of the current fitness questionnaire state for the row trailing label.
    private var fitnessGoalsSummary: String {
        let profile = UserFitnessProfile.current
        guard profile.completedAt != nil, let goal = profile.primaryGoal else {
            return "Not set"
        }
        return goal.title
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    if let email = authService.currentUser?.email {
                        settingsRow(icon: "envelope.fill", iconColor: Theme.accent, label: "Email", value: email)
                    }
                } header: {
                    XomMetricLabel("Account")
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.hairline)

                Section {
                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "bell.fill")
                                .frame(width: 24)
                                .foregroundStyle(Theme.accent)
                            Text("Notification Settings")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .tint(Theme.textTertiary)
                } header: {
                    XomMetricLabel("Notifications")
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.hairline)

                Section {
                    NavigationLink {
<<<<<<< HEAD
                        AICoachView()
                            .hideTabBar()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "sparkles")
                                .frame(width: 24)
                                .foregroundStyle(Theme.accent)
                            Text("AI Coach")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .tint(Theme.textTertiary)

                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "key.fill")
                            .frame(width: 24)
                            .foregroundStyle(Theme.accent)
                        SecureField("Anthropic API Key", text: $anthropicAPIKey)
                            .foregroundStyle(Theme.textPrimary)
                            .font(Theme.fontBody)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Anthropic API Key")
                            .accessibilityHint("Stored on this device only")
                    }
                } header: {
                    XomMetricLabel("AI Coach")
                } footer: {
                    Text("Stored on this device only. Get a key at console.anthropic.com.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
=======
                        FitnessQuestionnaireView(mode: .edit)
                            .navigationTitle("Fitness Goals")
                            .navigationBarTitleDisplayMode(.inline)
                            .hideTabBar()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "target")
                                .frame(width: 24)
                                .foregroundStyle(Theme.accent)
                            Text("Fitness Goals")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(fitnessGoalsSummary)
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .tint(Theme.textTertiary)
                } header: {
                    XomMetricLabel("Training")
>>>>>>> origin/master
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.hairline)

                Section {
                    settingsRow(icon: "info.circle.fill", iconColor: Theme.accent, label: "Version", value: appVersion)
                    settingsRow(icon: "building.2.fill", iconColor: Theme.accent, label: "App", value: Config.appName)
                } header: {
                    XomMetricLabel("About")
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.hairline)

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 24)
                                .foregroundStyle(Theme.destructive)
                            Text("Sign Out")
                                .foregroundStyle(Theme.destructive)
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.hairline)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be returned to the login screen.")
        }
    }

    private func settingsRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(iconColor)
            Text(label)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.textTertiary)
                .font(Theme.fontCaption)
        }
    }
}
