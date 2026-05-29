import SwiftUI

struct FeedDetailView: View {
    let item: SocialFeedItem
    let userId: String

    @State private var viewModel = FeedViewModel()
    @State private var localItem: SocialFeedItem
    @State private var fetchedWorkout: Workout?
    @State private var isLoadingWorkout = false
    @State private var showDeleteConfirm = false
    @State private var showEditCaption = false
    @State private var editedCaption = ""
    @Environment(\.dismiss) private var dismiss

    private var isOwnPost: Bool { item.userId == userId }

    init(item: SocialFeedItem, userId: String) {
        self.item = item
        self.userId = userId
        self._localItem = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    unifiedCard
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if isOwnPost {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editedCaption = localItem.caption ?? ""
                            showEditCaption = true
                        } label: {
                            Label("Edit Caption", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .confirmationDialog("Delete Post", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteFeedItem(id: item.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this post? This cannot be undone.")
        }
        .alert("Edit Caption", isPresented: $showEditCaption) {
            TextField("Caption", text: $editedCaption)
            Button("Save") {
                Task {
                    await viewModel.updateCaption(feedItemId: item.id, caption: editedCaption)
                    localItem.caption = editedCaption
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            if let activity = localItem.workoutActivity {
                isLoadingWorkout = true
                fetchedWorkout = await WorkoutService.shared.fetchWorkout(id: activity.workoutId)
                isLoadingWorkout = false
            }
        }
    }

    // MARK: - Unified Card

    private var unifiedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            headerRow

            if let caption = localItem.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }

            if let activity = localItem.workoutActivity {
                XomDivider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.workoutName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(Theme.fontCaption)
                        Text(localItem.createdAt.workoutDateString)
                        Text("·")
                        Image(systemName: "clock")
                            .font(Theme.fontCaption)
                        Text(formatDuration(activity.duration))
                    }
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 0) {
                    workoutStat(value: "\(activity.exerciseCount)", label: "Exercises", icon: "figure.strengthtraining.traditional")
                    workoutStat(value: "\(activity.totalSets)", label: "Sets", icon: "list.bullet")
                    workoutStat(value: formatVolume(activity.totalVolume), label: "Volume", icon: "scalemass")
                    if activity.prCount > 0 {
                        workoutStat(value: "\(activity.prCount)", label: "PRs", icon: "trophy.fill", color: Theme.prGold)
                    }
                }

                // Personal Records (#415) — dedicated gold section listing each
                // exercise that set a PR with the PR set details (weight × reps).
                personalRecordsSection

                XomDivider()

                // Real exercise data from DB
                exerciseSection

                // Soundtrack (#410). Respects `shareFullSoundtrack`:
                // - own post: always show everything
                // - other user's post: show all when share-full is on; show
                //   only the featured track when off
                if let workout = fetchedWorkout, !workout.tracks.isEmpty {
                    XomDivider()
                    soundtrackSection(workout: workout)
                }
            }

            XomDivider()

            actionBar
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Personal Records Section

    /// Gold-themed list of every exercise that set a PR in this workout, showing
    /// the specific PR set (weight × reps). Sourced from `fetchedWorkout` so it
    /// only renders once the real set data loads and a PR set actually exists.
    @ViewBuilder
    private var personalRecordsSection: some View {
        if let workout = fetchedWorkout {
            let prExercises = workout.exercises.filter { exercise in
                exercise.sets.contains(where: { $0.isPersonalRecord })
            }
            if !prExercises.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "trophy.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.prGold)
                        Text("Personal Records")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.prGold)
                        Spacer()
                    }

                    ForEach(prExercises) { exercise in
                        ForEach(exercise.sets.filter { $0.isPersonalRecord }) { prSet in
                            HStack(spacing: Theme.Spacing.sm) {
                                Text(exercise.exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(prSet.weight.formattedWeight)lb × \(prSet.reps)")
                                    .font(.subheadline.weight(.semibold).monospaced())
                                    .foregroundStyle(Theme.prGold)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.prGold.opacity(0.12))
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            }
        }
    }

    // MARK: - Exercise Section

    @ViewBuilder
    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            if isLoadingWorkout {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.md)
            } else if let workout = fetchedWorkout, !workout.exercises.isEmpty {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    realExerciseCard(exercise: exercise, index: index + 1)
                }

                // If DB has fewer exercises than the feed snapshot, show the missing
                // ones as summary rows (handles partial-save data).
                if let activity = localItem.workoutActivity,
                   activity.exercises.count > workout.exercises.count {
                    let dbNames = Set(workout.exercises.map { $0.exercise.name.lowercased() })
                    let missing = activity.exercises.filter { !dbNames.contains($0.name.lowercased()) }
                    ForEach(missing) { exercise in
                        fallbackExerciseRow(exercise: exercise)
                    }
                }
            } else if let activity = localItem.workoutActivity {
                // Fallback to summary data if fetch failed or workout has no exercises
                ForEach(activity.exercises) { exercise in
                    fallbackExerciseRow(exercise: exercise)
                }
            }
        }
    }

    private func realExerciseCard(exercise: WorkoutExercise, index: Int) -> some View {
        let totalVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        return VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, workoutSet in
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("\(setIndex + 1)")
                                .font(.caption.weight(.semibold).monospaced())
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 20, alignment: .leading)

                            Text("\(workoutSet.reps) × \(workoutSet.weight.formattedWeight)lb")
                                .font(.subheadline.weight(.semibold).monospaced())
                                .foregroundStyle(Theme.textPrimary)

                            if workoutSet.isPersonalRecord {
                                Image(systemName: "trophy.fill")
                                    .font(Theme.fontCaption2)
                                    .foregroundStyle(Theme.prGold)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("\(index)")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Theme.accent)
                        .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                        Text(exercise.exercise.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s") · \(formatVolume(totalVolume))")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(Theme.fontCaption2)
                            Text("PR")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.prGold)
                    }
                }
            }
            .tint(Theme.accent)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.background)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    /// Fallback when workout fetch fails — shows summary only
    private func fallbackExerciseRow(exercise: WorkoutActivity.ExerciseSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(Theme.fontSubheadline)
                .foregroundStyle(exercise.isPR ? Theme.prGold : Theme.accent)
                .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                .background((exercise.isPR ? Theme.prGold : Theme.accent).opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Best: \(exercise.bestWeight.formattedWeight) lbs x \(exercise.bestReps) reps")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if exercise.isPR {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill")
                        .font(Theme.fontCaption2)
                    Text("PR")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.prGold)
            }
        }
        .padding(10)
        .background(Theme.background)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // #367: avatar + display name push the poster's ProfileView.
            NavigationLink {
                ProfileView(userId: localItem.userId)
                    .hideTabBar()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    XomAvatar(
                        name: localItem.user.displayName.isEmpty ? localItem.user.username : localItem.user.displayName,
                        size: 48,
                        imageURL: localItem.user.avatarURL.flatMap { URL(string: $0) }
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                        Text(localItem.user.displayName.isEmpty ? localItem.user.username : localItem.user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(activityTypeLabel) · \(localItem.createdAt.timeAgo)")
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableCardStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            .accessibilityLabel("View profile of @\(localItem.user.username.isEmpty ? localItem.user.displayName : localItem.user.username)")
            .accessibilityHint("Opens this user's profile")

            Spacer()
        }
    }

    private var activityTypeLabel: String {
        switch localItem.activityType {
        case .workout:        "Workout"
        case .personalRecord: "Personal Record"
        case .milestone:      "Milestone"
        case .streak:         "Streak"
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                Haptics.selection()
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: localItem.isLiked ? "heart.fill" : "heart")
                        .font(Theme.fontBody)
                        .foregroundStyle(localItem.isLiked ? Theme.destructive : Theme.textSecondary)
                    Text("\(localItem.likes)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(localItem.isLiked ? "Unlike" : "Like"), \(localItem.likes) likes")

            NavigationLink {
                FeedCommentsView(feedItemId: item.id, userId: userId)
                    .hideTabBar()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(localItem.comments.count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(localItem.comments.count) comments")
            .accessibilityHint("Opens the comment thread")

            Button {
                shareFeedItem()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share")

            Spacer()
        }
    }

    // MARK: - Soundtrack (#410)

    /// Captured-soundtrack list shown under the workout summary. Respects the
    /// poster's `shareFullSoundtrack` toggle for non-owner views — when off,
    /// only the featured track surfaces. The owner always sees the full list
    /// so they can review what's stored on the workout.
    @ViewBuilder
    private func soundtrackSection(workout: Workout) -> some View {
        let visibleTracks = visibleTracks(in: workout)
        if !visibleTracks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Soundtrack")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(visibleTracks.count)")
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(visibleTracks.enumerated()), id: \.element.id) { index, track in
                        feedTrackRow(track: track, isFeatured: workout.featuredTrackId == track.id.uuidString)
                        if index < visibleTracks.count - 1 {
                            Divider()
                                .background(Theme.textSecondary.opacity(0.15))
                                .padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
                .background(Theme.background)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

                if !workout.shareFullSoundtrack && !isOwnPost {
                    Text("Only the featured track was shared.")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    /// Returns the slice of `workout.tracks` that should be displayed for the
    /// current viewer. Owner sees everything; friends see everything when
    /// `shareFullSoundtrack` is true, otherwise just the featured track.
    private func visibleTracks(in workout: Workout) -> [WorkoutTrack] {
        if isOwnPost || workout.shareFullSoundtrack {
            return workout.tracks
        }
        if let featured = workout.featuredTrack {
            return [featured]
        }
        return []
    }

    /// Single track row used inside the feed expanded soundtrack section. Wraps
    /// title/artist/source plus a trailing deep-link button.
    @ViewBuilder
    private func feedTrackRow(track: WorkoutTrack, isFeatured: Bool) -> some View {
        let deepLinkURL = WorkoutTrackDeepLink.url(for: track)
        HStack(spacing: Theme.Spacing.sm) {
            if isFeatured {
                Image(systemName: "star.fill")
                    .font(Theme.fontCaption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "music.note")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let artist = track.artist, !artist.isEmpty {
                        Text(artist)
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Text("\u{2022}")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityHidden(true)
                    }
                    Text(track.sourceApp)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            if let url = deepLinkURL {
                Button {
                    Haptics.light()
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(WorkoutTrackDeepLink.label(for: track.sourceApp))
                .accessibilityHint("Opens this track in \(track.sourceApp).")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Helpers

    private func workoutStat(value: String, label: String, icon: String, color: Color = Theme.accent) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            Image(systemName: icon)
                .font(Theme.fontSubheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
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

    private func shareFeedItem() {
        let name = localItem.user.displayName.isEmpty ? localItem.user.username : localItem.user.displayName
        var text = ""
        switch localItem.activityType {
        case .workout:
            if let w = localItem.workoutActivity {
                text = "\u{1F4AA} \(name) crushed \(w.workoutName)!\n\(w.exerciseCount) exercises \u{00B7} \(w.totalSets) sets \u{00B7} \(Int(w.totalVolume)) lbs"
                if w.prCount > 0 { text += " \u{00B7} \(w.prCount) PR\(w.prCount > 1 ? "s" : "")! \u{1F3C6}" }
            }
        case .personalRecord:
            if let pr = localItem.prActivity {
                text = "\u{1F3C6} \(name) hit a new PR!\n\(pr.exerciseName): \(Int(pr.weight)) lbs x \(pr.reps)"
            }
        case .milestone:
            if let m = localItem.milestoneActivity {
                text = "\u{1F389} \(name) reached a milestone!\n\(m.title) \u{2014} \(m.subtitle)"
            }
        case .streak:
            if let s = localItem.streakActivity {
                text = "\u{1F525} \(name) is on a \(s.currentStreak)-day streak!"
            }
        }
        text += "\n\nShared from XomFit"

        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(controller, animated: true)
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
            localItem.isLiked = wasLiked
            localItem.likes += wasLiked ? 1 : -1
        }
    }
}
