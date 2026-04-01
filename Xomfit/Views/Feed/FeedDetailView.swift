import SwiftUI

struct FeedDetailView: View {
    let item: SocialFeedItem
    let userId: String

    @State private var viewModel = FeedViewModel()
    @State private var comments: [FeedComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = false
    @State private var isPostingComment = false
    @State private var localItem: SocialFeedItem

    init(item: SocialFeedItem, userId: String) {
        self.item = item
        self.userId = userId
        self._localItem = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.paddingMedium) {
                        // The feed item card (non-interactive version)
                        FeedItemCard(
                            item: localItem,
                            onLike: { Task { await toggleLike() } },
                            onComment: {}
                        )

                        // Workout breakdown (if workout type)
                        if let activity = localItem.workoutActivity {
                            workoutBreakdown(activity: activity)
                        }

                        // Comments section
                        commentsSection
                    }
                    .padding(Theme.paddingMedium)
                }

                // Comment composer
                commentComposer
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadComments() }
    }

    // MARK: - Workout Breakdown

    private func workoutBreakdown(activity: WorkoutActivity) -> some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // Workout header
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.workoutName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(localItem.createdAt.workoutDateString)
                    Text("--")
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(formatDuration(activity.duration))
                }
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
            }

            // Stats row
            HStack(spacing: 0) {
                workoutStat(value: "\(activity.exerciseCount)", label: "Exercises", icon: "dumbbell.fill")
                workoutStat(value: "\(activity.totalSets)", label: "Sets", icon: "list.bullet")
                workoutStat(value: formatVolume(activity.totalVolume), label: "Volume", icon: "scalemass")
                if activity.prCount > 0 {
                    workoutStat(value: "\(activity.prCount)", label: "PRs", icon: "trophy.fill", color: Theme.prGold)
                }
            }

            // Exercise list
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Text("Exercises")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                ForEach(activity.exercises) { exercise in
                    exerciseCard(exercise: exercise)
                }
            }
        }
        .cardStyle()
    }

    private func workoutStat(value: String, label: String, icon: String, color: Color = Theme.accent) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func exerciseCard(exercise: WorkoutActivity.ExerciseSummary) -> some View {
        HStack(spacing: 12) {
            // Exercise icon
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 14))
                .foregroundStyle(exercise.isPR ? Theme.prGold : Theme.accent)
                .frame(width: 32, height: 32)
                .background((exercise.isPR ? Theme.prGold : Theme.accent).opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    if exercise.isPR {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text("PR")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.prGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.prGold.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 4))
                    }
                }

                Text("\(exercise.bestWeight.formattedWeight) lbs x \(exercise.bestReps) reps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.background)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.bestWeight.formattedWeight) pounds by \(exercise.bestReps) reps\(exercise.isPR ? ", personal record" : "")")
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 { return String(format: "%.1fk lbs", volume / 1000) }
        return "\(Int(volume)) lbs"
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Comments")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                }
                .padding(Theme.paddingMedium)
            } else if comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Theme.paddingMedium)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        HStack(spacing: Theme.paddingSmall) {
            TextField("Add a comment...", text: $newCommentText)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusSmall)

            Button {
                postComment()
            } label: {
                if isPostingComment {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newCommentText.isEmpty ? Theme.textSecondary : Theme.accent)
                }
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(Theme.cardBackground)
    }

    // MARK: - Actions

    private func loadComments() {
        isLoadingComments = true
        Task {
            do {
                comments = try await FeedService.shared.fetchComments(feedItemId: item.id)
            } catch {
                // Non-fatal
            }
            isLoadingComments = false
        }
    }

    private func postComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isPostingComment = true
        Task {
            do {
                try await FeedService.shared.postComment(
                    feedItemId: item.id,
                    userId: userId,
                    text: text
                )
                newCommentText = ""
                comments = try await FeedService.shared.fetchComments(feedItemId: item.id)
            } catch {
                // Non-fatal
            }
            isPostingComment = false
        }
    }

    private func toggleLike() async {
        let wasLiked = localItem.isLiked
        localItem.isLiked = !wasLiked
        localItem.likes += wasLiked ? -1 : 1

        do {
            if wasLiked {
                try await FeedService.shared.unlikeFeedItem(feedItemId: item.id, userId: userId)
            } else {
                try await FeedService.shared.likeFeedItem(feedItemId: item.id, userId: userId)
            }
        } catch {
            // Revert on failure
            localItem.isLiked = wasLiked
            localItem.likes += wasLiked ? 1 : -1
        }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: FeedComment

    var body: some View {
        HStack(alignment: .top, spacing: Theme.paddingSmall) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text(initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "User")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(comment.createdAt.timeAgo)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                Text(comment.text)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let name = comment.user?.displayName ?? "U"
        return String(name.prefix(2)).uppercased()
    }
}
