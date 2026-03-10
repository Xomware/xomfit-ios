import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if viewModel.isEditingProfile {
                    EditProfileView(viewModel: viewModel)
                } else {
                    ProfileDisplayView(viewModel: viewModel, authService: authService)
                }
            }
            .navigationTitle(viewModel.isEditingProfile ? "Edit Profile" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.initializeEditMode()
        }
    }
}

struct ProfileDisplayView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let authService: AuthService
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingLarge) {
                // Profile Header
                VStack(spacing: 12) {
                    // Avatar
                    if let avatarURL = viewModel.user.avatarURL, !avatarURL.isEmpty,
                       let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            case .loading:
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .empty:
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String(viewModel.user.displayName.prefix(1)))
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                    )
                            @unknown default:
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 80, height: 80)
                            }
                        }
                    } else {
                        Circle()
                            .fill(Theme.accent.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(viewModel.user.displayName.prefix(1)))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            )
                    }
                    
                    Text(viewModel.user.displayName)
                        .font(Theme.fontTitle)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("@\(viewModel.user.username)")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.user.isPrivate ? "lock.fill" : "globe")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        Text(viewModel.user.isPrivate ? "Private Profile" : "Public Profile")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    if !viewModel.user.bio.isEmpty {
                        Text(viewModel.user.bio)
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Theme.paddingMedium)
                
                // Edit Button
                Button(action: {
                    viewModel.isEditingProfile = true
                }) {
                    Text("Edit Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                }
                .padding(.horizontal, Theme.paddingMedium)
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ProfileStatCard(value: "\(viewModel.user.stats.totalWorkouts)", label: "Workouts")
                    ProfileStatCard(value: "\(viewModel.user.stats.totalPRs)", label: "PRs")
                    ProfileStatCard(value: "\(viewModel.user.stats.currentStreak)🔥", label: "Streak")
                }
                .padding(.horizontal, Theme.paddingMedium)
                
                // Total Volume
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Volume")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(Int(viewModel.user.stats.totalVolume / 1000))k lbs")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                    Spacer()
                    if let fav = viewModel.user.stats.favoriteExercise {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Favorite Lift")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                            Text(fav)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Theme.paddingMedium)
                
                // Recent PRs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Records")
                        .font(Theme.fontHeadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, Theme.paddingMedium)
                    
                    if viewModel.recentPRs.isEmpty {
                        Text("No personal records yet. Start logging workouts!")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, Theme.paddingMedium)
                    } else {
                        ForEach(viewModel.recentPRs) { pr in
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(Theme.prGold)
                                Text(pr.exerciseName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(pr.weight.formattedWeight) × \(pr.reps)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                            .cardStyle()
                            .padding(.horizontal, Theme.paddingMedium)
                        }
                    }
                }
                
                // Settings / Sign Out
                Button(action: {
                    Task {
                        try? await authService.signOut()
                    }
                }) {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.bottom, Theme.paddingLarge)
            }
        }
    }
}

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case displayName
        case bio
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingLarge) {
                // Avatar Section
                VStack(spacing: 12) {
                    // Avatar Display
                    if let selectedImage = viewModel.selectedAvatarImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let avatarURL = viewModel.user.avatarURL, !avatarURL.isEmpty,
                              let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            case .loading:
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            case .empty:
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(String(viewModel.editingDisplayName.prefix(1)))
                                            .font(.system(size: 44, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                    )
                            @unknown default:
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 100, height: 100)
                            }
                        }
                    } else {
                        Circle()
                            .fill(Theme.accent.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(viewModel.editingDisplayName.prefix(1)))
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            )
                    }
                    
                    // Upload Button
                    Button(action: { viewModel.showImagePicker = true }) {
                        Label("Change Avatar", systemImage: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                    .sheet(isPresented: $viewModel.showImagePicker) {
                        ImagePicker(selectedImage: $viewModel.selectedAvatarImage)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.paddingMedium)
                
                // Form Fields
                VStack(spacing: 16) {
                    // Display Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        TextField("Enter display name", text: $viewModel.editingDisplayName)
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textPrimary)
                            .padding(12)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .focused($focusedField, equals: .displayName)
                    }
                    
                    // Bio
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bio")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(viewModel.editingBio.count)/150")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        TextEditor(text: $viewModel.editingBio)
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textPrimary)
                            .frame(height: 100)
                            .padding(8)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .focused($focusedField, equals: .bio)
                            .onChange(of: viewModel.editingBio) { oldValue, newValue in
                                if newValue.count > 150 {
                                    viewModel.editingBio = String(newValue.prefix(150))
                                }
                            }
                    }
                    
                    // Privacy Toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Privacy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.editingIsPrivate ? "Private Profile" : "Public Profile")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text(viewModel.editingIsPrivate ? "Only you can see your profile" : "Anyone can see your profile")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.editingIsPrivate)
                                .tint(Theme.accent)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            let imageData = viewModel.selectedAvatarImage?
                                .jpegData(compressionQuality: 0.8)
                            await viewModel.saveProfile(avatarImageData: imageData)
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .foregroundColor(Theme.textPrimary)
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .cornerRadius(Theme.cornerRadius)
                    
                    Button(action: {
                        viewModel.cancelEdit()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent.opacity(0.1))
                            .cornerRadius(Theme.cornerRadius)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.top, Theme.paddingMedium)
                
                if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Theme.destructive)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.destructive)
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                }
                
                Spacer()
            }
            .padding(.vertical, Theme.paddingMedium)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ProfileStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}
