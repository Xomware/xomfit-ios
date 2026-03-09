import SwiftUI
import CoreLocation
import MapKit

struct GymCheckInView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = GymCheckInViewModel()
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.activeCheckIn == nil {
                    ProgressView("Loading...")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.paddingLarge) {
                            // Active check-in or check-in prompt
                            activeSection
                            
                            // Friends at this gym
                            if viewModel.activeCheckIn != nil && !viewModel.friendCheckIns.isEmpty {
                                friendsSection
                            }
                            
                            // Nearby gyms (when not checked in)
                            if viewModel.activeCheckIn == nil {
                                nearbySection
                            }
                            
                            // Recent check-ins history
                            historySection
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.bottom, Theme.paddingLarge)
                    }
                    .refreshable {
                        if let userId = authService.currentUser?.id {
                            await viewModel.load(userId: userId, userLocation: locationService.lastLocation)
                        }
                    }
                }
            }
            .navigationTitle("Gym Check-in")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showingCheckInSheet) {
                CheckInSheet(viewModel: viewModel)
            }
            .confirmationDialog("Check Out?", isPresented: $viewModel.showingCheckOutConfirm, titleVisibility: .visible) {
                Button("Check Out", role: .destructive) {
                    Task { await viewModel.checkOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let dur = viewModel.activeCheckIn?.formattedDuration {
                    Text("You've been at \(viewModel.activeCheckIn?.gymName ?? "the gym") for \(dur)")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Success", isPresented: Binding(
                get: { viewModel.checkOutSuccessMessage != nil },
                set: { if !$0 { viewModel.checkOutSuccessMessage = nil } }
            )) {
                Button("Nice!") { viewModel.checkOutSuccessMessage = nil }
            } message: {
                Text(viewModel.checkOutSuccessMessage ?? "")
            }
        }
        .task {
            if let userId = authService.currentUser?.id {
                await viewModel.load(userId: userId, userLocation: locationService.lastLocation)
            }
        }
        .onChange(of: locationService.lastLocation) { _, newLocation in
            guard let location = newLocation else { return }
            Task { await viewModel.refreshNearby(userLocation: location) }
        }
    }
    
    // MARK: - Active Check-In Section
    
    @ViewBuilder private var activeSection: some View {
        if let checkIn = viewModel.activeCheckIn {
            // Active check-in card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Checked in", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        
                        Text(checkIn.gymName ?? "Gym")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        
                        if let addr = checkIn.gymAddress {
                            Text(addr)
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Timer
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                        Text(checkIn.formattedDuration)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                
                if let note = checkIn.note {
                    HStack {
                        Text("\"\(note)\"")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .italic()
                        Spacer()
                    }
                }
                
                // Friends here
                if !viewModel.friendCheckIns.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(viewModel.friendCheckIns.prefix(5)) { friend in
                            AvatarBubble(name: friend.userDisplayName ?? "?")
                        }
                        if viewModel.friendCheckIns.count > 5 {
                            Text("+\(viewModel.friendCheckIns.count - 5) more")
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.leading, 12)
                        }
                    }
                }
                
                // Check out button
                Button {
                    viewModel.showingCheckOutConfirm = true
                } label: {
                    if viewModel.isCheckingOut {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Label("Check Out", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.black)
                .background(Theme.accent)
                .cornerRadius(Theme.cornerRadius)
                .disabled(viewModel.isCheckingOut)
            }
            .padding(Theme.paddingMedium)
            .background(
                LinearGradient(
                    colors: [Theme.accent.opacity(0.15), Theme.cardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(Theme.cornerRadius)
        } else {
            // Not checked in — prompt
            VStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent.opacity(0.7))
                
                Text("Not checked in")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                
                Text("Head to a gym and check in to see which friends are there with you.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                
                if viewModel.nearbyGyms.isEmpty {
                    Label("Looking for nearby gyms...", systemImage: "location.magnifyingglass")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.paddingLarge)
            .cardStyle()
        }
    }
    
    // MARK: - Friends Section
    
    @ViewBuilder private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Also here now")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            
            ForEach(viewModel.friendCheckIns) { friend in
                FriendCheckInRow(checkIn: friend)
            }
        }
    }
    
    // MARK: - Nearby Gyms Section
    
    @ViewBuilder private var nearbySection: some View {
        if !viewModel.nearbyGyms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nearby Gyms")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                
                ForEach(viewModel.nearbyGyms) { gym in
                    NearbyGymRow(
                        gym: gym,
                        distanceLabel: locationService.lastLocation.map { loc in
                            viewModel.distanceLabel(to: gym, from: loc)
                        },
                        inRange: locationService.lastLocation.map { loc in
                            viewModel.isWithinRange(of: gym, userLocation: loc)
                        } ?? false
                    ) {
                        viewModel.startCheckIn(gym: gym)
                    }
                }
            }
        }
    }
    
    // MARK: - History Section
    
    @ViewBuilder private var historySection: some View {
        if !viewModel.recentCheckIns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Check-ins")
                        .font(Theme.fontHeadline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(viewModel.totalWorkoutsThisMonth) this month")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.accent)
                }
                
                ForEach(viewModel.recentCheckIns.prefix(10)) { checkIn in
                    CheckInHistoryRow(checkIn: checkIn)
                }
            }
        }
    }
}

// MARK: - Check-In Sheet

struct CheckInSheet: View {
    @ObservedObject var viewModel: GymCheckInViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: Theme.paddingLarge) {
                    // Gym info
                    if let gym = viewModel.selectedGym {
                        VStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.accent)
                            Text(gym.name)
                                .font(Theme.fontHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            if let addr = gym.address {
                                Text(addr)
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Theme.paddingLarge)
                        .cardStyle()
                    }
                    
                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Note (optional)")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                        TextField("e.g. Leg day 🦵, PR attempt...", text: $viewModel.checkInNote, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .padding(Theme.paddingMedium)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    
                    // Privacy
                    Toggle(isOn: $viewModel.checkInIsPublic) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.checkInIsPublic ? "globe" : "lock.fill")
                                .foregroundStyle(viewModel.checkInIsPublic ? Theme.accent : Theme.textSecondary)
                            VStack(alignment: .leading) {
                                Text(viewModel.checkInIsPublic ? "Public" : "Private")
                                    .font(Theme.fontBody)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(viewModel.checkInIsPublic ? "Friends can see you're here" : "Only visible to you")
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .tint(Theme.accent)
                    .padding(Theme.paddingMedium)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    
                    Spacer()
                    
                    // Check in button
                    Button {
                        Task {
                            guard let userId = authService.currentUser?.id else { return }
                            await viewModel.confirmCheckIn(userId: userId)
                        }
                    } label: {
                        if viewModel.isCheckingIn {
                            ProgressView().tint(.black)
                        } else {
                            Label("Check In Now", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(Theme.accent)
                    .cornerRadius(Theme.cornerRadius)
                    .disabled(viewModel.isCheckingIn)
                }
                .padding(Theme.paddingMedium)
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct AvatarBubble: View {
    let name: String
    var initials: String {
        name.split(separator: " ").compactMap { $0.first }.map(String.init).joined()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.8))
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
            Text(String(initials.prefix(2)))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

private struct FriendCheckInRow: View {
    let checkIn: GymCheckIn
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarBubble(name: checkIn.userDisplayName ?? "?")
                .scaleEffect(1.2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.userDisplayName ?? "Friend")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Here for \(checkIn.formattedDuration)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Theme.accent.opacity(0.6))
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct NearbyGymRow: View {
    let gym: Gym
    let distanceLabel: String?
    let inRange: Bool
    let onCheckIn: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(inRange ? Theme.accent : Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gym.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let dist = distanceLabel {
                    Text(dist)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            if inRange {
                Button("Check In") { onCheckIn() }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.accent)
                    .foregroundStyle(.black)
                    .cornerRadius(20)
            } else {
                Text("Out of range")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct CheckInHistoryRow: View {
    let checkIn: GymCheckIn
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(checkIn.checkedInAt.formatted(.dateTime.month(.abbreviated)))
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                Text(checkIn.checkedInAt.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(checkIn.gymName ?? "Gym")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                
                HStack(spacing: 8) {
                    Label(checkIn.checkedInAt.formatted(.dateTime.hour().minute()),
                          systemImage: "clock")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    if !checkIn.formattedDuration.isEmpty {
                        Text("· \(checkIn.formattedDuration)")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent.opacity(0.5))
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}
