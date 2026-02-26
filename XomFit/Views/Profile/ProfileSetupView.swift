import SwiftUI
import PhotosUI

/// Onboarding flow shown the first time a new user lands on the Profile tab.
/// Guides them through: welcome → name/username → avatar → bio.
struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authService: AuthService

    @State private var step: Int = 0
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var pendingImageData: Data?

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.top, Theme.paddingLarge)

                Spacer(minLength: 40)

                stepContent
                    .padding(.horizontal, Theme.paddingMedium)
                    .animation(.easeInOut(duration: 0.3), value: step)

                Spacer(minLength: 40)

                navigationButtons
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.bottom, Theme.paddingLarge)
            }
        }
        .onAppear {
            // Pre-fill name from auth metadata if available
            if let authUser = authService.currentUser {
                displayName = authUser.displayName
                username = authUser.username
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.accent : Theme.cardBackground)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: nameStep
        case 2: avatarStep
        case 3: bioStep
        default: EmptyView()
        }
    }

    // Step 0 – Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundColor(Theme.accent)

            VStack(spacing: 12) {
                Text("Welcome to XomFit!")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Let's set up your profile so the community can follow your fitness journey.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // Step 1 – Name & Username
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should we call you?")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                Text("You can always change this later.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
            }

            SetupFormField(label: "Display Name", placeholder: "John Doe", text: $displayName)

            // Username with @ prefix
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
                HStack(spacing: 6) {
                    Text("@")
                        .foregroundColor(Theme.textSecondary)
                        .padding(.leading, 12)
                    TextField("username", text: $username)
                        .foregroundColor(Theme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .frame(height: 46)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    // Step 2 – Avatar
    private var avatarStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Add a profile photo")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                Text("Help others recognise you on the leaderboard.")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = previewImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Theme.cardBackground)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.textSecondary)
                                )
                        }
                    }

                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.background)
                        )
                        .offset(x: 4, y: 4)
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

            Button("Skip for now") { nextStep() }
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // Step 3 – Bio
    private var bioStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tell us about yourself")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                Text("What motivates you? What are your goals?")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(Theme.textPrimary)
                        .frame(height: 120)
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .onChange(of: bio) { _, newVal in
                            if newVal.count > 150 { bio = String(newVal.prefix(150)) }
                        }

                    if bio.isEmpty {
                        Text("e.g. Chasing that 405 deadlift 💪")
                            .foregroundColor(Theme.textSecondary.opacity(0.45))
                            .font(Theme.fontBody)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Spacer()
                    Text("\(bio.count)/150")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isSaving {
                ProgressView()
                    .tint(Theme.accent)
            } else {
                Button {
                    if step == totalSteps - 1 {
                        Task { await finish() }
                    } else {
                        nextStep()
                    }
                } label: {
                    Text(step == totalSteps - 1 ? "Let's Go! 💪" : "Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .cornerRadius(Theme.cornerRadius)
                }
                .disabled(step == 1 && !nameStepValid)

                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.destructive)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private var nameStepValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func nextStep() {
        withAnimation { step = min(step + 1, totalSteps - 1) }
    }

    private func finish() async {
        guard let userId = authService.currentUser?.id else { return }

        await viewModel.createProfile(
            userId: userId,
            displayName: displayName,
            username: username,
            bio: bio
        )

        // Upload avatar after profile row exists
        if let data = pendingImageData, viewModel.errorMessage == nil {
            await viewModel.uploadAvatar(imageData: data)
        }
    }
}

// MARK: - Setup Form Field (standalone; no horizontal padding applied inside)

struct SetupFormField: View {
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
    }
}
