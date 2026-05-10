import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var deleteAccountError: String? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil

    /// Anthropic API key override (per-user). v1: stored via @AppStorage --
    /// not secure. TODO: migrate to Keychain.
    @AppStorage("aiCoach.anthropicAPIKey") private var anthropicAPIKey: String = ""

    // MARK: - App Preferences (#312)

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    @AppStorage("restDuration") private var restDurationSeconds: Double = 90
    /// 0 = Sunday, 1 = Monday.
    @AppStorage("weekStartDay") private var weekStartDay: Int = 0
    /// "" = system, "light", "dark".
    @AppStorage("colorScheme") private var preferredColorSchemeRaw: String = ""

    // MARK: - Notifications top-level toggle (#312)

    @AppStorage("workoutRemindersEnabled") private var workoutRemindersEnabled: Bool = false
    @State private var notificationsAuthorized: Bool = false

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lbs
    }

    // MARK: - Computed

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var versionShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
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
                accountSection
                notificationsSection
                appPreferencesSection
                trainingSection
                aiCoachSection
                dataPrivacySection
                supportSection
                aboutSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await refreshNotificationStatus() }
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be returned to the login screen.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account and workouts. This cannot be undone.")
        }
        .alert("Couldn't delete account", isPresented: Binding(
            get: { deleteAccountError != nil },
            set: { if !$0 { deleteAccountError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
        .alert("Couldn't export workouts", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section {
            if let email = authService.currentUser?.email {
                settingsRow(icon: "envelope.fill", iconColor: Theme.accent, label: "Email", value: email)
            }
        } header: {
            XomMetricLabel("Account")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: workoutRemindersBinding) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "alarm.fill")
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout reminders")
                            .foregroundStyle(Theme.textPrimary)
                        if !notificationsAuthorized {
                            Text("Push permission required")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .tint(Theme.accent)
            .accessibilityHint("Master switch for workout reminder push notifications")

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
    }

    private var appPreferencesSection: some View {
        Section {
            // Weight unit
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "scalemass.fill")
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Text("Weight unit")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("Weight unit", selection: $weightUnitRaw) {
                    Text("lbs").tag(WeightUnit.lbs.rawValue)
                    Text("kg").tag(WeightUnit.kg.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .accessibilityLabel("Weight unit")
            }

            // Default rest duration (seconds)
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "timer")
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Stepper(value: $restDurationSeconds, in: 30...600, step: 15) {
                    HStack {
                        Text("Default rest")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(formatRest(restDurationSeconds))
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                }
                .accessibilityLabel("Default rest duration")
                .accessibilityValue(formatRest(restDurationSeconds))
            }

            // Week start day
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "calendar")
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Text("Week starts on")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("Week starts on", selection: $weekStartDay) {
                    Text("Sun").tag(0)
                    Text("Mon").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .accessibilityLabel("Week starts on")
            }

            // Theme
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "paintbrush.fill")
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Text("Theme")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("Theme", selection: $preferredColorSchemeRaw) {
                    Text("System").tag("")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                .accessibilityLabel("Theme")
            }
        } header: {
            XomMetricLabel("App Preferences")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var trainingSection: some View {
        Section {
            NavigationLink {
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

            NavigationLink {
                ReportsListView()
                    .hideTabBar()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    Text("Reports")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .tint(Theme.textTertiary)
        } header: {
            XomMetricLabel("Training")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var aiCoachSection: some View {
        Section {
            NavigationLink {
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
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var dataPrivacySection: some View {
        Section {
            Button {
                Task { await exportWorkouts() }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    Text("Export workouts")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if isExporting {
                        ProgressView().tint(Theme.accent)
                    }
                }
            }
            .disabled(isExporting)
            .accessibilityLabel("Export workouts")
            .accessibilityHint("Builds a CSV of your sets and opens the share sheet")

            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "trash.fill")
                        .frame(width: 24)
                        .foregroundStyle(Theme.destructive)
                    Text("Delete account")
                        .foregroundStyle(Theme.destructive)
                }
            }
        } header: {
            XomMetricLabel("Data & Privacy")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var supportSection: some View {
        Section {
            Button {
                openFeedbackMail()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "envelope.open.fill")
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    Text("Send feedback")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .accessibilityHint("Opens Mail with a prefilled feedback message")

            Button {
                requestAppReview()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "star.fill")
                        .frame(width: 24)
                        .foregroundStyle(Theme.prGold)
                    Text("Rate XomFit")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .accessibilityHint("Prompts the App Store rating sheet")

            Link(destination: URL(string: "https://xomware.com/privacy")!) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "lock.shield.fill")
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    Text("Privacy Policy")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .accessibilityHint("Opens xomware.com/privacy in your browser")
        } header: {
            XomMetricLabel("Support")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var aboutSection: some View {
        Section {
            settingsRow(icon: "info.circle.fill", iconColor: Theme.accent, label: "Version", value: appVersion)
            settingsRow(icon: "building.2.fill", iconColor: Theme.accent, label: "App", value: Config.appName)
        } header: {
            XomMetricLabel("About")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var signOutSection: some View {
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

    // MARK: - Bindings

    /// Custom binding so flipping the master toggle on triggers a permission
    /// prompt when the system has not yet authorized push.
    private var workoutRemindersBinding: Binding<Bool> {
        Binding(
            get: { workoutRemindersEnabled && notificationsAuthorized },
            set: { newValue in
                workoutRemindersEnabled = newValue
                if newValue && !notificationsAuthorized {
                    Task {
                        await NotificationService.shared.requestPermission()
                        await refreshNotificationStatus()
                        // If the system denied, drop the master switch back to off.
                        if !notificationsAuthorized {
                            workoutRemindersEnabled = false
                        }
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func formatRest(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        if m == 0 { return "\(s)s" }
        if s == 0 { return "\(m)m" }
        return "\(m)m \(s)s"
    }

    private func refreshNotificationStatus() async {
        await NotificationService.shared.checkPermission()
        notificationsAuthorized = NotificationService.shared.isPermissionGranted
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

    // MARK: - Actions

    private func exportWorkouts() async {
        guard let userId = authService.currentUser?.id.uuidString.lowercased() else {
            exportError = "Sign in required"
            return
        }
        isExporting = true
        defer { isExporting = false }

        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
        guard !workouts.isEmpty else {
            exportError = "No workouts to export yet."
            return
        }

        let csv = CSVExporter.csv(for: workouts, unit: weightUnit)
        do {
            let url = try CSVExporter.writeToTempFile(csv: csv)
            presentShareSheet(items: [url])
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch {
            deleteAccountError = error.localizedDescription
        }
    }

    private func openFeedbackMail() {
        let version = versionShort
        let build = buildNumber
        let iosVersion = UIDevice.current.systemVersion
        let device = UIDevice.current.model
        let body = """


        ---
        App version: \(version) (\(build))
        iOS: \(iosVersion)
        Device: \(device)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "dominickj.giordano@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "XomFit Feedback"),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func presentShareSheet(items: [Any]) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let root = scene.keyWindow?.rootViewController else { return }
        // Walk to the topmost presented controller so the share sheet sits above any modal.
        var top: UIViewController = root
        while let presented = top.presentedViewController {
            top = presented
        }
        // iPad popover anchor.
        if let pop = controller.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(
                x: top.view.bounds.midX,
                y: top.view.bounds.midY,
                width: 0,
                height: 0
            )
            pop.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
    }
}
