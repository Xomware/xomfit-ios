import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter controls
                VStack(spacing: Theme.paddingSmall) {
                    HStack {
                        Text("Feed")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.accentColor)
                        }
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                    
                    CustomFeedFilterControl(selectedFilter: $viewModel.selectedFilter)
                        .onChange(of: viewModel.selectedFilter) { _ in
                            viewModel.applyFilter()
                        }
                }
                .padding(.vertical, Theme.paddingSmall)
                .background(Color.white.opacity(0.02))
                
                // Feed content
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(Theme.accentColor)
                        Text("Loading feed...")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else if viewModel.posts.isEmpty {
                    VStack(spacing: Theme.paddingMedium) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No activity yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Follow friends to see their workouts, PRs, and milestones")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, Theme.paddingMedium)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.paddingMedium) {
                            ForEach(viewModel.posts) { post in
                                WorkoutActivityCard(post: post) {
                                    viewModel.toggleLike(post: post)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.vertical, Theme.paddingSmall)
                    }
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .background(Theme.background)
        }
    }
}
