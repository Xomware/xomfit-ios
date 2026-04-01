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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Header row: avatar + name + badge + timestamp
            headerRow

            // Activity-specific content
            activityContent

            // Caption
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, 2)
            }

            Divider()
                .background(Theme.textSecondary.opacity(0.3))

            // Action bar: like + comment counts
            actionBar
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
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
        HStack(spacing: Theme.paddingSmall) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(avatarInitials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.user.displayName.isEmpty ? item.user.username : item.user.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(item.createdAt.timeAgo)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            activityBadge

            // Owner actions menu (delete / edit)
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Post options")
            }
        }
    }

    private var avatarInitials: String {
        let name = item.user.displayName.isEmpty ? item.user.username : item.user.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Activity Badge

    private var activityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(badgeLabel)
                .font(Theme.fontSmall)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(Theme.cornerRadiusSmall)
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
        case .workout: return Theme.accent
        case .personalRecord: return Theme.prGold
        case .milestone: return Color(hex: "AA66FF")
        case .streak: return Color(hex: "FF6633")
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
        HStack(spacing: Theme.paddingLarge) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: 5) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundColor(item.isLiked ? Theme.destructive : Theme.textSecondary)
                    Text("\(item.likes)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Comment button
            Button(action: onComment) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(item.comments.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Save workout button (only for workout posts from others)
            if item.activityType == .workout, let onSave {
                Button {
                    Haptics.success()
                    onSave()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 15))
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
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text(activity.workoutName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: Theme.paddingLarge) {
                miniStat(icon: "clock", value: formatDuration(activity.duration))
                miniStat(icon: "scalemass", value: formatVolume(activity.totalVolume))
                miniStat(icon: "list.bullet", value: "\(activity.totalSets) sets")
                if activity.prCount > 0 {
                    miniStat(icon: "trophy.fill", value: "\(activity.prCount) PR", color: Theme.prGold)
                }
            }

            if !activity.exercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activity.exercises.prefix(4)) { ex in
                            HStack(spacing: 3) {
                                if ex.isPR {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.prGold)
                                }
                                Text(ex.name)
                                    .font(Theme.fontSmall)
                                    .foregroundColor(ex.isPR ? Theme.prGold : Theme.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.background)
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }

    private func miniStat(icon: String, value: String, color: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
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
}

// MARK: - PR Activity Content

private struct PRActivityContent: View {
    let activity: PRActivity

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.prGold)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(activity.weight.formattedWeight) lbs × \(activity.reps) reps")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Theme.prGold)
                if let prev = activity.previousBest {
                    Text("Previous best: \(prev.formattedWeight) lbs")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            if let imp = activity.improvement, imp > 0 {
                Spacer()
                Text("+\(imp.formattedWeight)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.prGold.opacity(0.08))
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Milestone Activity Content

private struct MilestoneActivityContent: View {
    let activity: MilestoneActivity

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Text(activity.icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(activity.subtitle)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(activity.badge)
                .font(Theme.fontSmall)
                .foregroundColor(Color(hex: "AA66FF"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "AA66FF").opacity(0.15))
                .cornerRadius(6)
        }
        .padding(Theme.paddingMedium)
        .background(Color(hex: "AA66FF").opacity(0.08))
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Streak Activity Content

private struct StreakActivityContent: View {
    let activity: StreakActivity

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "FF6633"))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(activity.currentStreak) Day Streak")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(hex: "FF6633"))
                if activity.isNewRecord {
                    Text("New personal streak record!")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.accent)
                } else {
                    Text("Previous best: \(activity.previousBest) days")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Theme.paddingMedium)
        .background(Color(hex: "FF6633").opacity(0.08))
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}
