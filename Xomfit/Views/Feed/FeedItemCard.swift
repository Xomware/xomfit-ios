import SwiftUI

// MARK: - Identifiable URL wrapper for photo zoom sheet

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

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
    @State private var zoomPhotoURL: IdentifiableURL? = nil
    @State private var particleBurst = false

    var body: some View {
        XomCard(variant: .base) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                headerRow
                activityContent

                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 2)
                }

                XomDivider()

                actionBar
            }
        }
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
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this post? This cannot be undone.")
        }
        .alert("Edit Caption", isPresented: $showEditCaption) {
            TextField("Caption", text: $editedCaption)
            Button("Save") { onEdit?(editedCaption) }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $zoomPhotoURL) { identifiable in
            PhotoZoomView(url: identifiable.url)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            XomAvatar(
                name: item.user.displayName.isEmpty ? item.user.username : item.user.displayName,
                size: 48
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.user.displayName.isEmpty ? item.user.username : item.user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                // Activity context line under display name
                Text("\(activityTypeLabel) · \(item.createdAt.timeAgo)")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityLabel("\(activityTypeLabel), \(item.createdAt.timeAgo)")
            }

            Spacer()

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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Post options")
            }
        }
    }

    // MARK: - Activity Content

    @ViewBuilder
    private var activityContent: some View {
        switch item.activityType {
        case .workout:
            if let activity = item.workoutActivity {
                WorkoutActivityContent(activity: activity, onPhotoTap: { url in
                    zoomPhotoURL = IdentifiableURL(url: url)
                })
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
            // Like button with particle burst on first like
            Button {
                let wasLiked = item.isLiked
                withAnimation(.xomCelebration) { likeScale = 1.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.xomPlayful) { likeScale = 1 }
                }
                if !wasLiked {
                    particleBurst = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        particleBurst = true
                    }
                }
                onLike()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(item.isLiked ? Theme.destructive : Theme.textSecondary)
                        .scaleEffect(likeScale)
                        .overlay(
                            ParticleBurstView(
                                trigger: particleBurst,
                                symbols: ["heart.fill"],
                                color: Theme.destructive,
                                count: 6,
                                duration: 0.6
                            )
                        )
                    Text("\(item.likes)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: item.isLiked)
            .accessibilityLabel("\(item.isLiked ? "Unlike" : "Like"), \(item.likes) likes")

            // Comment button
            Button(action: onComment) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(item.comments.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.comments.count) comments")

            Spacer()

            // Share button
            Button { shareFeedItem() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")

            if item.activityType == .workout, let onSave {
                Button {
                    Haptics.success()
                    onSave()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save workout")
            }
        }
    }

    // MARK: - Computed labels

    private var activityTypeLabel: String {
        switch item.activityType {
        case .workout:       "Workout"
        case .personalRecord: "Personal Record"
        case .milestone:     "Milestone"
        case .streak:        "Streak"
        }
    }

    // MARK: - Share

    private func shareFeedItem() {
        let name = item.user.displayName.isEmpty ? item.user.username : item.user.displayName
        var text = ""
        switch item.activityType {
        case .workout:
            if let w = item.workoutActivity {
                text = "\(name) crushed \(w.workoutName)! \(w.exerciseCount) exercises · \(w.totalSets) sets · \(Int(w.totalVolume)) lbs"
                if w.prCount > 0 { text += " · \(w.prCount) PR\(w.prCount > 1 ? "s" : "")!" }
            }
        case .personalRecord:
            if let pr = item.prActivity {
                text = "\(name) hit a new PR! \(pr.exerciseName): \(Int(pr.weight)) lbs x \(pr.reps)"
            }
        case .milestone:
            if let m = item.milestoneActivity {
                text = "\(name) reached a milestone! \(m.title) — \(m.subtitle)"
            }
        case .streak:
            if let s = item.streakActivity {
                text = "\(name) is on a \(s.currentStreak)-day streak!"
            }
        }
        text += "\n\nShared from XomFit"
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}

// MARK: - Workout Activity Content

private struct WorkoutActivityContent: View {
    let activity: WorkoutActivity
    let onPhotoTap: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(activity.workoutName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)

                if let rating = activity.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        }
                    }
                }
            }

            if let location = activity.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(location)
                        .font(Theme.fontSmall)
                }
                .foregroundStyle(Theme.textSecondary)
            }

            // Stats row — 3 columns with XomStat
            HStack(spacing: 0) {
                XomStat(formatDuration(activity.duration), label: "Duration")
                XomStat(formatVolume(activity.totalVolume), label: "Volume")
                XomStat("\(activity.totalSets)", label: "Sets")
            }
            .padding(.vertical, Theme.Spacing.xs)

            if activity.prCount > 0 {
                XomBadge("\(activity.prCount) PR\(activity.prCount > 1 ? "s" : "")", icon: "trophy.fill", color: Theme.prGold, variant: .display)
            }

            // Photo gallery with tap-to-zoom
            if let photoURLs = activity.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(photoURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .foregroundStyle(Theme.textSecondary)
                                    default:
                                        ProgressView()
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(.rect(cornerRadius: 8))
                                .contentShape(Rectangle())
                                .onTapGesture { onPhotoTap(url) }
                                .accessibilityLabel("Workout photo")
                            }
                        }
                    }
                }
            }

            // Exercise pills using XomBadge
            if !activity.exercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activity.exercises.prefix(4)) { ex in
                            XomBadge(
                                ex.name,
                                icon: ex.isPR ? "trophy.fill" : nil,
                                color: ex.isPR ? Theme.prGold : Theme.textSecondary,
                                variant: .secondary
                            )
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

    /// Display unit for weight values. Stored values stay lbs.
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    var body: some View {
        ActivityStripeCard(stripeColor: Theme.prGold, icon: "trophy.fill", title: activity.exerciseName) {
            Text(activity.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("\(activity.weight.formattedWeight(unit: weightUnit)) \(weightUnit.displayName) × \(activity.reps) reps")
                .font(Theme.fontDisplay)
                .foregroundStyle(Theme.prGold)
                .accessibilityLabel("\(activity.weight.formattedWeight(unit: weightUnit)) \(weightUnit.accessibilityName), \(activity.reps) reps")

            if let prev = activity.previousBest {
                Text("Previous best: \(prev.formattedWeight(unit: weightUnit)) \(weightUnit.displayName)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
            }

            if let imp = activity.improvement, imp > 0 {
                XomBadge("+\(imp.formattedWeight(unit: weightUnit)) \(weightUnit.displayName)", color: Theme.accent, variant: .display)
            }
        }
    }
}

// MARK: - Milestone Activity Content

private struct MilestoneActivityContent: View {
    let activity: MilestoneActivity

    var body: some View {
        ActivityStripeCard(stripeColor: Theme.milestone, icon: "star.fill", title: activity.title) {
            Text(activity.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(activity.subtitle)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
            XomBadge(activity.badge, color: Theme.milestone, variant: .display)
        }
    }
}

// MARK: - Streak Activity Content

private struct StreakActivityContent: View {
    let activity: StreakActivity

    var body: some View {
        ActivityStripeCard(stripeColor: Theme.streak, icon: "flame.fill", title: "\(activity.currentStreak) Day Streak") {
            Text("\(activity.currentStreak) Day Streak")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.streak)

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
    }
}
