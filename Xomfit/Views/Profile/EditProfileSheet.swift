import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    let viewModel: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Form {
                    // MARK: - Avatar (#368)
                    Section {
                        avatarSection
                            .listRowBackground(Theme.surface)
                    } footer: {
                        if let avatarError = viewModel.avatarErrorMessage {
                            Text(avatarError)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.destructive)
                        } else {
                            Text("Tap your photo to change it.")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Section("Username") {
                        TextField("username", text: Bindable(viewModel).editUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .listRowBackground(Theme.surface)
                            .foregroundStyle(Theme.textPrimary)
                            .onChange(of: viewModel.editUsername) { _, _ in
                                viewModel.checkUsernameAvailability(userId: userId)
                            }

                        if viewModel.isCheckingUsername {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text("Checking availability...")
                                    .font(Theme.fontSmall)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .listRowBackground(Theme.surface)
                        } else if let error = viewModel.usernameError {
                            Text(error)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.destructive)
                                .listRowBackground(Theme.surface)
                        }
                    }

                    Section("Display Name") {
                        TextField("Your name", text: Bindable(viewModel).editDisplayName)
                            .listRowBackground(Theme.surface)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Section("Bio") {
                        TextField("Tell people about yourself", text: Bindable(viewModel).editBio, axis: .vertical)
                            .lineLimit(3...5)
                            .listRowBackground(Theme.surface)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Section {
                        Toggle("Private Account", isOn: Bindable(viewModel).editIsPrivate)
                            .tint(Theme.accent)
                            .listRowBackground(Theme.surface)
                            .foregroundStyle(Theme.textPrimary)
                    } footer: {
                        Text("Only friends can see your activity when your account is private.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Save") {
                            Haptics.success()
                            Task {
                                await viewModel.updateProfile(userId: userId)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.canSaveProfile ? Theme.accent : Theme.textSecondary)
                        .disabled(!viewModel.canSaveProfile)
                    }
                }
            }
        }
        .presentationCornerRadius(Theme.Radius.lg)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        // Capture main-actor-isolated view-model state into locals before the
        // PhotosPicker label closure (which is nonisolated under the iOS 26
        // SDK / Swift 6 strict concurrency).
        let avatarName = viewModel.displayName.isEmpty ? viewModel.username : viewModel.displayName
        let avatarURL = viewModel.avatarURL
        let isUploading = viewModel.isUploadingAvatar

        return HStack(spacing: Theme.Spacing.md) {
            PhotosPicker(
                selection: Bindable(viewModel).avatarPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    XomAvatar(
                        name: avatarName,
                        size: 80,
                        imageURL: URL(string: avatarURL ?? "")
                    )

                    if isUploading {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .tint(.white)
                    } else {
                        // Small camera affordance so the tap target is discoverable.
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.black)
                            )
                            .overlay(
                                Circle().stroke(Theme.surface, lineWidth: 2)
                            )
                            .offset(x: 28, y: 28)
                    }
                }
                .frame(width: 80, height: 80)
            }
            .disabled(isUploading)
            .accessibilityLabel("Change profile photo")
            .accessibilityAddTraits(.isButton)
            .onChange(of: viewModel.avatarPickerItem) { _, newItem in
                guard let newItem else { return }
                print("[ProfileAvatar] PhotosPicker selection changed — kicking off updateAvatar")
                Task {
                    await viewModel.updateAvatar(item: newItem, userId: userId)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text("Profile Photo")
                    .font(Theme.fontSubheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if isUploading {
                    Text("Uploading...")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("JPEG, square crop recommended.")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.tight)
        .frame(minHeight: 44)
    }
}
