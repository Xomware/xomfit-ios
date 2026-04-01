import SwiftUI

struct FeedItemCard: View {
    let item: SocialFeedItem
    let onLike: () -> Void
    let onComment: () -> Void
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    var onSave: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showEditCaption = false
    @State private var editedCaption = ""
    @State private var likeScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            headerRow
            activityContent

            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 2)
            }

            Divider()
                .background(Theme.textSecondary.opacity(0.3))

            actionBar
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .contextMenu {
            if onEdit != nil {
                Button {
                    editedCaption = item.caption ?? ""
                    showEditCaption = true
                } label: {
                    Label("Edit Caption", systemImage: "pencil")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete Post", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this post? This cannot be undone.")
        }
        .alert("Edit Caption", isPresented: $showEditCaption) {
            TextField("Caption", text: $editedCaption)
            Button("Save") {
                onEdit?(editedCaption)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            XomAvatar(
                name: item.user.displayName.isEmpty ? item.user.username : item.user.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.user.displayName.isEmpty ? item.user.username : item.user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(item.createdAt.timeAgo)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            activityBadge

            if onDelete != nil || onEdit != nil {
                Menu {
                    if onEdit != nil {
                        Button {
                            editedCaption = item.caption ?? ""
                            showEditCaption = true
                        } label: {
                            Label("Edit Caption", systemImage: "pencil")
                        }
                    }
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Post options")
            }
        }
    }

    // MARK: - Activity Badge

    private var activityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(Theme.fontSmall)
            Text(badgeLabel)
                .font(Theme.fontSmall)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(badgeColor.opacity(0.15))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    private var badgeIcon: String {
        switch item.activityType {
        case .workout: return "dumbbell.fill"
        case .personalRecord: return "trophy.fill"
        case .milestone: return "star.fill"
        case .streak: return "flame.fill"
        }
    }

    private var badgeLabel: String {
        switch item.activityType {
        case .workout: return "Workout"
        case .personalRecord: return "PR"
        case .milestone: return "Milestone"
        case .streak: return "Streak"
        }
    }

    private var badgeColor: Color {
        switch item.activityType {
        case .workout: return Theme.badgeWorkout
        case .personalRecord: return Theme.badgePR
        case .milestone: return Theme.badgeMilestone
        case .streak: return Theme.badgeStreak
        }
    }

    // MARK: - Activity Content

    @ViewBuilder
    private var activityContent: some View {
        switch item.activityType {
        case .workout:
            if let activity = item.workoutActivity {
                WorkoutActivityContent(activity: activity)
            }
        case .personalRecord:
            if let activity = item.prActivity {
                PRActivityContent(activity: activity)
            }
        case .milestone:
            if let activity = item.milestoneActivity {
                MilestoneActivityContent(activity: activity)
            }
        case .streak:
            if let activity = item.streakActivity {
                StreakActivityContent(activity: activity)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Like button with animation
            Button {
                withAnimation(.xomCelebration) {
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.xomPlayful) {
                        likeScale = 1
                    }
                }
                onLike()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundStyle(item.isLiked ? Theme.destructive : Theme.textSecondary)
                        .scaleEffect(likeScale)
                    Text("\(item.likes)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: item.isLiked)

            // Comment button
            Button(action: onComment) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(item.comments.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if item.activityType == .workout, let onSave {
                Button {
                    Haptics.success()
                    onSave()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save workout")
            }
        }
    }
}

// MARK: - Workout Activity Content

private struct WorkoutActivityContent: View {
    let activity: WorkoutActivity

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(activity.workoutName)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            // Stats grid — max 3 primary + optional PR badge
            HStack(spacing: 0) {
                XomStat(formatDuration(activity.duration), label: "Duration", icon: "clock", iconColor: Theme.textSecondary)
                XomStat(formatVolume(activity.totalVolume), label: "Volume", icon: "scalemass", iconColor: Theme.textSecondary)
                XomStat("\(activity.totalSets)", label: "Sets", icon: "list.bullet", iconColor: Theme.textSecondary)
            }
            .padding(.vertical, Theme.Spacing.xs)

            if activity.prCount > 0 {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "trophy.fill")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.prGold)
                    Text("\(activity.prCount) PR\(activity.prCount > 1 ? "s" : "")")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.prGold)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.prGold.opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))
            }

            if !activity.exercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activity.exercises.prefix(4)) { ex in
                            HStack(spacing: 3) {
                                if ex.isPR {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.prGold)
                                }
                                Text(ex.name)
                                    .font(Theme.fontSmall)
                                    .foregroundStyle(ex.isPR ? Theme.prGold : Theme.textSecondary)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(Theme.background)
                            .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 { return String(format: "%.1fk", volume / 1000) }
        return "\(Int(volume))"
    }
}

// MARK: - PR Activity Content

private struct PRActivityContent: View {
    let activity: PRActivity

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.prGold)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(activity.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(activity.weight.formattedWeight) lbs × \(activity.reps) reps")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.prGold)
                if let prev = activity.previousBest {
                    Text("Previous best: \(prev.formattedWeight) lbs")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if let imp = activity.improvement, imp > 0 {
                Spacer()
                Text("+\(imp.formattedWeight)")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.prGold.opacity(0.08))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }
}

// MARK: - Milestone Activity Content

private struct MilestoneActivityContent: View {
    let activity: MilestoneActivity

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(activity.icon)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(activity.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(activity.subtitle)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Text(activity.badge)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.badgeMilestone)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.badgeMilestone.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.badgeMilestone.opacity(0.08))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }
}

// MARK: - Streak Activity Content

private struct StreakActivityContent: View {
    let activity: StreakActivity

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.badgeStreak)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(activity.currentStreak) Day Streak")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.badgeStreak)
                if activity.isNewRecord {
                    Text("New personal streak record!")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("Previous best: \(activity.previousBest) days")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.badgeStreak.opacity(0.08))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }
}
