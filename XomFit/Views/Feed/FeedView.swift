import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.paddingMedium) {
                        ForEach(FeedFilter.allCases, id: \.self) { filter in
                            FilterTabView(
                                label: filter.rawValue,
                                isSelected: viewModel.selectedFilter == filter,
                                action: {
                                    viewModel.changeFilter(to: filter)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.vertical, Theme.paddingSmall)
                }
                .background(Theme.secondaryBackground)
                .border(Theme.divider, width: 0.5)
                
                // Posts Feed
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.accent)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else if viewModel.posts.isEmpty {
                    VStack(spacing: Theme.paddingMedium) {
                        Spacer()
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary)
                        Text("No workouts yet")
                            .font(Theme.fontHeadline)
                            .foregroundColor(Theme.textPrimary)
                        Text("Follow friends or discover public workouts")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.paddingMedium) {
                            ForEach(viewModel.posts) { post in
                                FeedPostCardView(
                                    post: post,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.vertical, Theme.paddingSmall)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Feed")
            .refreshable {
                viewModel.refresh()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { error in
                Button("OK") { }
            } message: { error in
                Text(error)
            }
        }
    }
}

struct FilterTabView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.accent.opacity(0.15) : Color.clear)
                .cornerRadius(Theme.cornerRadiusSmall)
        }
    }
}

struct FeedPostCardView: View {
    @State var post: FeedPost
    let viewModel: FeedViewModel
    @State private var showCommentSheet = false
    @State private var showReactionPicker = false
    @State private var commentText = ""
    
    let reactionEmojis = ["💪", "🔥", "👏", "❤️", "🎉", "😍"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — User info + time
            HStack {
                Circle()
                    .fill(Theme.accent.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.user.displayName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(post.createdAt.timeAgo)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if post.workout.totalPRs > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Theme.prGold)
                            .font(.system(size: 12))
                        Text("PR!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.prGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.prGold.opacity(0.15))
                    .cornerRadius(Theme.cornerRadiusSmall)
                }
            }
            
            // Workout Name
            Text(post.workout.name)
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            
            // Stats Row
            HStack(spacing: 20) {
                StatBadge(icon: "clock", value: post.workout.durationString, label: "Duration")
                StatBadge(icon: "flame.fill", value: post.workout.formattedVolume, label: "Volume")
                StatBadge(icon: "number", value: "\(post.workout.totalSets)", label: "Sets")
                StatBadge(icon: "figure.strengthtraining.traditional", value: "\(post.workout.exercises.count)", label: "Exercises")
            }
            
            // Exercise Summary
            VStack(alignment: .leading, spacing: 6) {
                ForEach(post.workout.exercises) { ex in
                    HStack {
                        Text(ex.exercise.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if let best = ex.bestSet {
                            Text(best.displaySet)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.cornerRadiusSmall)
            
            // Reactions Row
            if !post.reactionCounts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(post.reactionCounts.keys).sorted(), id: \.self) { emoji in
                        HStack(spacing: 4) {
                            Text(emoji)
                                .font(.system(size: 14))
                            Text("\(post.reactionCounts[emoji] ?? 0)")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.1))
                        .cornerRadius(6)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.paddingSmall)
            }
            
            // Actions
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    // Like
                    Button(action: {
                        viewModel.toggleLike(post: post)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                .foregroundColor(post.isLiked ? .red : Theme.textSecondary)
                            Text("\(post.likes)")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .font(.system(size: 14))
                    }
                    
                    // Comment
                    Button(action: {
                        showCommentSheet.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .foregroundColor(Theme.textSecondary)
                            Text("\(post.comments.count)")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .font(.system(size: 14))
                    }
                    
                    // Reaction
                    Menu {
                        ForEach(reactionEmojis, id: \.self) { emoji in
                            Button(action: {
                                viewModel.addReaction(to: post, emoji: emoji)
                            }) {
                                Text("\(emoji)")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup")
                                .foregroundColor(Theme.textSecondary)
                            Text("React")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    // Share
                    Button(action: {
                        // Share to pasteboard or other sharing options
                        UIPasteboard.general.string = "Check out this workout: \(post.workout.name) by \(post.user.displayName)"
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.textSecondary)
                            .font(.system(size: 14))
                    }
                }
                
                // Comments Preview
                if !post.comments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(post.comments.prefix(2)) { comment in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Theme.accent.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(String(comment.user.displayName.prefix(1)))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(comment.user.displayName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(comment.createdAt.timeAgo)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Text(comment.text)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                        }
                        
                        if post.comments.count > 2 {
                            Button(action: { showCommentSheet.toggle() }) {
                                Text("View all \(post.comments.count) comments")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.cornerRadiusSmall)
                }
            }
        }
        .cardStyle()
        .sheet(isPresented: $showCommentSheet) {
            CommentSheetView(
                post: $post,
                commentText: $commentText,
                viewModel: viewModel,
                isPresented: $showCommentSheet
            )
        }
    }
}

struct CommentSheetView: View {
    @Binding var post: FeedPost
    @Binding var commentText: String
    let viewModel: FeedViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section("Comments") {
                        if post.comments.isEmpty {
                            Text("No comments yet. Be the first!")
                                .foregroundColor(Theme.textSecondary)
                        } else {
                            ForEach(post.comments) { comment in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(Theme.accent.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(comment.user.displayName.prefix(1)))
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(comment.user.displayName)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text(comment.createdAt.timeAgo)
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Text(comment.text)
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                }
                                .listRowBackground(Theme.secondaryBackground)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                
                // Comment Input
                VStack(spacing: Theme.paddingSmall) {
                    HStack(spacing: Theme.paddingSmall) {
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, Theme.paddingSmall)
                        
                        Button(action: {
                            viewModel.addComment(to: post, text: commentText)
                            commentText = ""
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(commentText.isEmpty ? Theme.textSecondary : Theme.accent)
                        }
                        .disabled(commentText.isEmpty)
                    }
                    .padding(Theme.paddingMedium)
                }
                .background(Theme.secondaryBackground)
                .border(Theme.divider, width: 0.5)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.accent)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
