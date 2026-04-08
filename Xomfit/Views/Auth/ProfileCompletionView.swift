import SwiftUI
import Supabase

struct ProfileCompletionView: View {
    @Environment(AuthService.self) private var authService
    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var usernameError: String?
    @State private var isCheckingUsername = false
    @State private var usernameCheckTask: Task<Void, Never>?

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && usernameError == nil
            && !isCheckingUsername
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Form {
                    displayNameSection
                    usernameSection
                    bioSection
                    submitSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Display Name

    private var displayNameSection: some View {
        Section("Display Name") {
            TextField("Your name", text: $displayName)
                .textContentType(.name)
                .listRowBackground(Theme.surface)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("Display name")
        }
    }

    // MARK: - Username

    private var usernameSection: some View {
        Section {
            HStack(spacing: 4) {
                Text("@")
                    .foregroundStyle(Theme.textSecondary)
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityLabel("Username")
                    .onChange(of: username) { _, newValue in
                        debouncedUsernameCheck(newValue)
                    }

                if isCheckingUsername {
                    ProgressView()
                        .tint(Theme.accent)
                        .controlSize(.small)
                }
            }
            .listRowBackground(Theme.surface)

            if let usernameError {
                Text(usernameError)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.destructive)
                    .listRowBackground(Theme.surface)
            }
        } header: {
            Text("Username")
        }
    }

    // MARK: - Bio

    private var bioSection: some View {
        Section("Bio (optional)") {
            TextField("Tell people about yourself", text: $bio, axis: .vertical)
                .lineLimit(3...5)
                .listRowBackground(Theme.surface)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("Bio")
        }
    }

    // MARK: - Submit

    private var submitSection: some View {
        Section {
            Button {
                Task { await saveProfile() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Continue")
                            .font(.body.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .disabled(!isFormValid || isSaving)
            .listRowBackground(isFormValid && !isSaving ? Theme.accent : Theme.accent.opacity(0.4))
            .foregroundStyle(.black)
            .accessibilityLabel("Continue")
            .accessibilityHint("Saves your profile information")

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.destructive)
                    .listRowBackground(Theme.surface)
            }
        }
    }

    // MARK: - Username Validation

    private func debouncedUsernameCheck(_ value: String) {
        usernameCheckTask?.cancel()
        usernameError = nil

        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            do {
                let existing: [ProfileRow] = try await supabase
                    .from("profiles")
                    .select("id")
                    .eq("username", value: trimmed)
                    .neq("id", value: userId)
                    .limit(1)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }

                if !existing.isEmpty {
                    usernameError = "Username already taken"
                }
            } catch {
                guard !Task.isCancelled else { return }
                // Network error during check — don't block the user
            }

            isCheckingUsername = false
        }
    }

    // MARK: - Save

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            try await ProfileService.shared.upsertProfile(
                userId: userId,
                username: username.trimmingCharacters(in: .whitespaces),
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                bio: bio.trimmingCharacters(in: .whitespaces),
                avatarURL: nil,
                isPrivate: false
            )
            authService.profileCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
