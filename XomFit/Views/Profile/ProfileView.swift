import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Profile Header
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Theme.accent.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(viewModel.user.displayName.prefix(1)))
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(Theme.accent)
                                )
                            
                            Text(viewModel.user.displayName)
                                .font(Theme.fontTitle)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("@\(viewModel.user.username)")
                                .font(Theme.fontBody)
                                .foregroundColor(Theme.textSecondary)
                            
                            if !viewModel.user.bio.isEmpty {
                                Text(viewModel.user.bio)
                                    .font(Theme.fontBody)
                                    .foregroundColor(Theme.textPrimary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, Theme.paddingMedium)
                        
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
                        
                        // Settings / Sign Out
                        Button(action: { authService.signOut() }) {
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
            .navigationTitle("Profile")
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
