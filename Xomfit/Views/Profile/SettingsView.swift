import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignOutConfirm = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section("Account") {
                    if let email = authService.currentUser?.email {
                        settingsRow(icon: "envelope.fill", iconColor: Theme.accent, label: "Email", value: email)
                    }
                }
                .listRowBackground(Theme.cardBackground)

                Section("About") {
                    settingsRow(icon: "info.circle.fill", iconColor: Theme.accent, label: "Version", value: appVersion)
                    settingsRow(icon: "building.2.fill", iconColor: Theme.accent, label: "App", value: Config.appName)
                }
                .listRowBackground(Theme.cardBackground)

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack(spacing: Theme.paddingMedium) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 24)
                                .foregroundColor(Theme.destructive)
                            Text("Sign Out")
                                .foregroundColor(Theme.destructive)
                        }
                    }
                    .listRowBackground(Theme.cardBackground)
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
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(iconColor)
            Text(label)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textSecondary)
                .font(Theme.fontCaption)
        }
    }
}
