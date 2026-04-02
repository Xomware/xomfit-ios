import SwiftUI

struct EditProfileSheet: View {
    let viewModel: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Form {
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
    }
}
