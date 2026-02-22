import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.paddingMedium) {
                    ForEach(viewModel.posts) { post in
                        WorkoutCardView(post: post) {
                            viewModel.toggleLike(post: post)
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.top, Theme.paddingSmall)
            }
            .background(Theme.background)
            .navigationTitle("Feed")
            .refreshable {
                viewModel.refresh()
            }
        }
    }
}
