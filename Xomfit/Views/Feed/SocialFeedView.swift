import SwiftUI

struct SocialFeedView: View {
    @StateObject private var viewModel = SocialFeedViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feedHeader
                filterBar
                feedContent
            }
            .background(Theme.background)
            .task {
                await viewModel.loadFeed()
            }
        }
    }

    // MARK: - Header

    private var feedHeader: some View {
        HStack {
            Text("Feed")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.accentColor)
            }
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accentColor)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        CustomFeedFilterControl(selectedFilter: $viewModel.selectedFilter)
            .onChange(of: viewModel.selectedFilter) { newFilter in
                Task {
                    await viewModel.changeFilter(to: newFilter)
                }
            }
            .padding(.bottom, Theme.paddingSmall)
            .background(Color.white.opacity(0.02))
    }

    // MARK: - Feed Content

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading {
            feedLoadingState
        } else if let error = viewModel.errorMessage {
            feedErrorState(error)
        } else if viewModel.feedItems.isEmpty {
            feedEmptyState
        } else {
            feedList
        }
    }

    private var feedLoadingState: some View {
        VStack(spacing: Theme.paddingSmall) {
            ProgressView()
                .tint(Theme.accentColor)
            Text("Loading feed...")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity)
    }

    private func feedErrorState(_ error: String) -> some View {
        VStack(spacing: Theme.paddingMedium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadFeed() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.accentColor)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, Theme.paddingMedium)
    }

    private var feedEmptyState: some View {
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
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.paddingMedium) {
                ForEach(viewModel.feedItems) { item in
                    SocialFeedCard(item: item) {
                        Task { await viewModel.toggleLike(item: item) }
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Theme.accentColor)
                        .padding()
                }
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, Theme.paddingSmall)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Social Feed Card (routes to correct card type)

struct SocialFeedCard: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void

    var body: some View {
        switch item.activityType {
        case .workout:
            SocialWorkoutCard(item: item, onLikeTap: onLikeTap)
        case .personalRecord:
            SocialPRCard(item: item, onLikeTap: onLikeTap)
        case .milestone:
            SocialMilestoneCard(item: item, onLikeTap: onLikeTap)
        case .streak:
            SocialStreakCard(item: item, onLikeTap: onLikeTap)
        }
    }
}

// MARK: - Shared Card Header

struct FeedCardHeader: View {
    let user: AppUser
    let subtitle: String
    let timeAgo: String

    var body: some View {
        HStack(spacing: Theme.paddingSmall) {
            Circle()
                .fill(Theme.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(user.displayName.prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(timeAgo)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Shared Engagement Bar

struct FeedEngagementBar: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void
    @State private var showComments = false

    var body: some View {
        VStack(spacing: Theme.paddingSmall) {
            HStack(spacing: Theme.paddingMedium) {
                Button(action: onLikeTap) {
                    HStack(spacing: 4) {
                        Image(systemName: item.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(item.isLiked ? .red : .gray)
                        Text("\(item.likes)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Button(action: { showComments.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(item.comments.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .foregroundColor(.gray)
                        Text("Share")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }

            // Comment preview
            if !item.comments.isEmpty && !showComments {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.comments.prefix(2)) { comment in
                        HStack(alignment: .top, spacing: Theme.paddingSmall) {
                            Circle()
                                .fill(Theme.accentColor.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Text(String((comment.user?.displayName ?? "?").prefix(1)))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.accentColor)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.user?.displayName ?? "User")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(comment.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.paddingSmall)
    }
}

// MARK: - Workout Card

struct SocialWorkoutCard: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            FeedCardHeader(
                user: item.user,
                subtitle: "completed a workout",
                timeAgo: item.createdAt.timeAgoDisplay
            )

            if let workout = item.workoutActivity {
                workoutContent(workout)
            }

            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.horizontal, Theme.paddingSmall)
            }

            FeedEngagementBar(item: item, onLikeTap: onLikeTap)
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func workoutContent(_ workout: WorkoutActivity) -> some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.workoutName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: Theme.paddingMedium) {
                        Label(formatDuration(workout.duration), systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Label("\(workout.totalSets) sets", systemImage: "list.number")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Label(formatVolume(workout.totalVolume), systemImage: "scalemass")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if workout.prCount > 0 {
                    VStack(alignment: .center, spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.accentColor)
                        Text("\(workout.prCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("PRs")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, Theme.paddingSmall)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }

            // Exercise list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(workout.exercises.prefix(3)) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("\(Int(exercise.bestWeight)) lbs × \(exercise.bestReps)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if exercise.isPR {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("PR")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(Theme.accentColor)
                        }
                    }
                    .padding(.horizontal, Theme.paddingSmall)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(6)
                }

                if workout.exercises.count > 3 {
                    Text("+\(workout.exercises.count - 3) more")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, Theme.paddingSmall)
                }
            }
        }
        .padding(Theme.paddingSmall)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return "\(Int(volume)) lbs"
    }
}

// MARK: - PR Card

struct SocialPRCard: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            FeedCardHeader(
                user: item.user,
                subtitle: "hit a new personal record!",
                timeAgo: item.createdAt.timeAgoDisplay
            )

            if let pr = item.prActivity {
                prContent(pr)
            }

            FeedEngagementBar(item: item, onLikeTap: onLikeTap)
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func prContent(_ pr: PRActivity) -> some View {
        VStack(spacing: Theme.paddingMedium) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW PR!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.accentColor)
                    Text(pr.exerciseName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: Theme.paddingMedium) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            HStack(spacing: 0) {
                                Text("\(Int(pr.weight))")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text(" lbs")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reps")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text("\(pr.reps)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                Spacer()

                if let improvement = pr.improvement, improvement > 0 {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.accentColor)
                        Text("+\(Int(improvement))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("from last")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, Theme.paddingSmall)
                    .padding(.vertical, 12)
                    .background(Theme.accentColor.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(Theme.paddingMedium)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
        }
    }
}

// MARK: - Milestone Card

struct SocialMilestoneCard: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            FeedCardHeader(
                user: item.user,
                subtitle: item.milestoneActivity?.subtitle ?? "reached a milestone!",
                timeAgo: item.createdAt.timeAgoDisplay
            )

            if let milestone = item.milestoneActivity {
                milestoneContent(milestone)
            }

            FeedEngagementBar(item: item, onLikeTap: onLikeTap)
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func milestoneContent(_ milestone: MilestoneActivity) -> some View {
        VStack(spacing: Theme.paddingSmall) {
            HStack(spacing: Theme.paddingMedium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(milestone.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(milestone.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: milestone.icon)
                        .font(.system(size: 28))
                        .foregroundColor(Theme.accentColor)
                    Text(milestone.badge)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accentColor)
                }
                .padding(Theme.paddingMedium)
                .background(Theme.accentColor.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(Theme.paddingMedium)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)

            if !milestone.details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(milestone.details, id: \.self) { detail in
                        HStack(spacing: Theme.paddingSmall) {
                            Circle()
                                .fill(Theme.accentColor)
                                .frame(width: 4, height: 4)
                            Text(detail)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
        }
    }
}

// MARK: - Streak Card

struct SocialStreakCard: View {
    let item: SocialFeedItem
    let onLikeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            FeedCardHeader(
                user: item.user,
                subtitle: "is on a workout streak!",
                timeAgo: item.createdAt.timeAgoDisplay
            )

            if let streak = item.streakActivity {
                streakContent(streak)
            }

            FeedEngagementBar(item: item, onLikeTap: onLikeTap)
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func streakContent(_ streak: StreakActivity) -> some View {
        HStack(spacing: Theme.paddingMedium) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0))
                    Text("\(streak.currentStreak)-Day Streak")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                if streak.isNewRecord {
                    Text("New personal best!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accentColor)
                }

                Text("Previous best: \(streak.previousBest) days")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            if streak.isNewRecord {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0))
                    .padding(Theme.paddingMedium)
                    .background(Color(red: 1.0, green: 0.84, blue: 0).opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

#Preview {
    SocialFeedView()
}
