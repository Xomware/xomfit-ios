import SwiftUI

struct FeedDetailView: View {
    let item: SocialFeedItem
    let userId: String

    @State private var viewModel = FeedViewModel()
    @State private var localItem: SocialFeedItem

    init(item: SocialFeedItem, userId: String) {
        self.item = item
        self.userId = userId
        self._localItem = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.paddingMedium) {
                    // Unified card: header + workout stats + exercises
                    unifiedCard

                    // Comments navigation button
                    NavigationLink {
                        FeedCommentsView(feedItemId: item.id, userId: userId)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 16))
                            Text("Comments")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(localItem.comments.count)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.paddingMedium)
                        .background(Theme.cardBackground)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.paddingMedium)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Unified Card

    private var unifiedCard: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // User info header
            headerRow

            // Caption
            if let caption = localItem.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }

            // Workout breakdown (if workout type)
            if let activity = localItem.workoutActivity {
                Divider().background(Theme.textSecondary.opacity(0.2))

                // Workout name + date
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

                // Exercise list with sets/weights
                Divider().background(Theme.textSecondary.opacity(0.2))

                VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                    Text("Exercises")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(activity.exercises) { exercise in
                        exerciseRow(exercise: exercise)
                    }
                }
            }

            Divider().background(Theme.textSecondary.opacity(0.2))

            // Action bar (like)
            actionBar
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Theme.paddingSmall) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(avatarInitials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localItem.user.displayName.isEmpty ? localItem.user.username : localItem.user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(localItem.createdAt.timeAgo)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            activityBadge
        }
    }

    private var avatarInitials: String {
        let name = localItem.user.displayName.isEmpty ? localItem.user.username : localItem.user.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var activityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(badgeLabel)
                .font(Theme.fontSmall)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    private var badgeIcon: String {
        switch localItem.activityType {
        case .workout: return "dumbbell.fill"
        case .personalRecord: return "trophy.fill"
        case .milestone: return "star.fill"
        case .streak: return "flame.fill"
        }
    }

    private var badgeLabel: String {
        switch localItem.activityType {
        case .workout: return "Workout"
        case .personalRecord: return "PR"
        case .milestone: return "Milestone"
        case .streak: return "Streak"
        }
    }

    private var badgeColor: Color {
        switch localItem.activityType {
        case .workout: return Theme.accent
        case .personalRecord: return Theme.prGold
        case .milestone: return Color(hex: "AA66FF")
        case .streak: return Color(hex: "FF6633")
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Theme.paddingLarge) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: localItem.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundStyle(localItem.isLiked ? Theme.destructive : Theme.textSecondary)
                    Text("\(localItem.likes)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Workout Helpers

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

    private func exerciseRow(exercise: WorkoutActivity.ExerciseSummary) -> some View {
        HStack(spacing: 12) {
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
        .padding(10)
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

    // MARK: - Actions

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
            localItem.isLiked = wasLiked
            localItem.likes += wasLiked ? 1 : -1
        }
    }
}
