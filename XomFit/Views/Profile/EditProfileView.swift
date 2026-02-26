import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isPrivate: Bool = false

    // Avatar picker state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var previewImage: UIImage?

    // Toast
    @State private var showSuccessToast = false

    private let bioLimit = 150

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        avatarSection
                        formSection
                        privacySection

                        // Save Button
                        saveButton
                            .padding(.horizontal, Theme.paddingMedium)
                            .padding(.bottom, Theme.paddingLarge)
                    }
                    .padding(.top, Theme.paddingMedium)
                }

                // Success toast overlay
                if showSuccessToast {
                    toastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .onAppear(perform: populateFields)
            .errorAlert(message: viewModel.errorMessage) {
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = previewImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            AvatarView(
                                avatarURL: viewModel.user.avatarURL,
                                displayName: viewModel.user.displayName,
                                size: 96
                            )
                        }
                    }

                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.background)
                        )
                        .offset(x: 3, y: 3)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        pendingImageData = data
                        previewImage = UIImage(data: data)
                    }
                }
            }

            Text("Tap to change photo")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Form Fields

    private var formSection: some View {
        VStack(spacing: 14) {
            ProfileFormField(label: "Display Name", placeholder: "Your name", text: $displayName)
            ProfileFormField(label: "Username", placeholder: "username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            // Bio — multiline
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)

                TextEditor(text: $bio)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Theme.textPrimary)
                    .font(Theme.fontBody)
                    .frame(height: 88)
                    .padding(12)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > bioLimit {
                            bio = String(newValue.prefix(bioLimit))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(bio.count)/\(bioLimit)")
                        .font(Theme.fontCaption)
                        .foregroundColor(bio.count >= bioLimit ? Theme.destructive : Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.paddingMedium)
        }
    }

    // MARK: - Privacy Toggle

    private var privacySection: some View {
        HStack(spacing: 14) {
            Image(systemName: isPrivate ? "lock.fill" : "globe")
                .foregroundColor(isPrivate ? Theme.warning : Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(isPrivate ? "Private Profile" : "Public Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(isPrivate
                     ? "Only approved followers see your workouts"
                     : "Anyone can view your profile and workouts")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isPrivate)
                .tint(Theme.accent)
                .labelsHidden()
        }
        .cardStyle()
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(Theme.background)
                } else {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.background)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent)
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(viewModel.isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.accent)
            Text("Profile updated!")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func populateFields() {
        displayName = viewModel.user.displayName
        username    = viewModel.user.username
        bio         = viewModel.user.bio
        isPrivate   = viewModel.user.isPrivate
    }

    private func save() async {
        // Upload avatar first if the user selected a new one
        if let data = pendingImageData {
            await viewModel.uploadAvatar(imageData: data)
            guard viewModel.errorMessage == nil else { return }
            pendingImageData = nil
            previewImage = nil
        }

        await viewModel.updateProfile(
            displayName: displayName,
            username: username,
            bio: bio,
            isPrivate: isPrivate
        )

        if viewModel.errorMessage == nil {
            withAnimation(.spring()) { showSuccessToast = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSuccessToast = false }
            dismiss()
        }
    }
}

// MARK: - Shared Form Field

struct ProfileFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)

            TextField(placeholder, text: $text)
                .foregroundColor(Theme.textPrimary)
                .padding(12)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
}

// MARK: - Error Alert Helper

extension View {
    func errorAlert(message: String?, onDismiss: @escaping () -> Void) -> some View {
        alert("Something went wrong", isPresented: .init(
            get: { message != nil },
            set: { if !$0 { onDismiss() } }
        )) {
            Button("OK") { onDismiss() }
        } message: {
            Text(message ?? "")
        }
    }
}
