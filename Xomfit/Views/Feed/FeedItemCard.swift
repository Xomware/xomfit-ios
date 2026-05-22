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

    /// Disables the like-button particle burst + scale punch when Reduce Motion is on.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        XomCard(variant: .base) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                headerRow

                // Anthem row (#403) — surfaces the poster's profile anthem on
                // each feed card with a play-the-30s-preview affordance. Nil
                // when the user hasn't picked an anthem.
                if let anthem = item.user.anthem {
                    AnthemRow(anthem: anthem, style: .feed)
                }

                // Featured soundtrack row (#410) — surfaces the poster's
                // featured-track pick from this workout in the same compact
                // anthem-row style. Nil when no featured pick was made.
                if let activity = item.workoutActivity,
                   let featuredTitle = activity.featuredTrackTitle,
                   !featuredTitle.isEmpty {
                    FeaturedSoundtrackRow(
                        title: featuredTitle,
                        artist: activity.featuredTrackArtist ?? "",
                        sourceApp: activity.featuredTrackSource ?? "",
                        deepLinkURL: featuredDeepLinkURL(activity: activity),
                        autoPlay: shouldAutoPlay(featuredTitle: featuredTitle)
                    )
                }

                activityContent

                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, Theme.Spacing.tighter)
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
            // #367: avatar + display name push the poster's ProfileView.
            // Nested inside the parent NavigationLink that opens FeedDetailView —
            // SwiftUI's NavigationStack routes taps to the inner link when the
            // tap hits its frame, leaving the rest of the card to the parent.
            NavigationLink {
                ProfileView(userId: item.userId)
                    .hideTabBar()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    XomAvatar(
                        name: item.user.displayName.isEmpty ? item.user.username : item.user.displayName,
                        size: 48,
                        imageURL: item.user.avatarURL.flatMap { URL(string: $0) }
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                        Text(item.user.displayName.isEmpty ? item.user.username : item.user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)

                        // Activity context line under display name
                        Text("\(activityTypeLabel) · \(item.createdAt.timeAgo)")
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableCardStyle())
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            .accessibilityLabel("View profile of @\(item.user.username.isEmpty ? item.user.displayName : item.user.username)")
            .accessibilityHint("Opens this user's profile")

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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Post options")
                .accessibilityHint("Edit caption or delete this post")
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
            // Like button with particle burst on first like.
            // Both the punch animation and the particle overlay respect Reduce Motion.
            Button {
                let wasLiked = item.isLiked
                if !reduceMotion {
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
                }
                onLike()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(item.isLiked ? Theme.destructive : Theme.textSecondary)
                        .scaleEffect(reduceMotion ? 1 : likeScale)
                        .overlay(
                            Group {
                                if !reduceMotion {
                                    ParticleBurstView(
                                        trigger: particleBurst,
                                        symbols: ["heart.fill"],
                                        color: Theme.destructive,
                                        count: 6,
                                        duration: 0.6
                                    )
                                }
                            }
                        )
                    Text("\(item.likes)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
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
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.comments.count) comments")
            .accessibilityHint("Opens the comment thread")

            Spacer()

            // Share button
            Button { shareFeedItem() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
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

    // MARK: - Featured soundtrack helper (#410)

    /// Builds a deep-link `URL` from the captured payload fields. Falls through
    /// to a synthesized `WorkoutTrack` so we can reuse the shared resolver
    /// without having to fetch the full workout just to render the feed card.
    private func featuredDeepLinkURL(activity: WorkoutActivity) -> URL? {
        guard let title = activity.featuredTrackTitle, !title.isEmpty else { return nil }
        let synthesized = WorkoutTrack(
            title: title,
            artist: activity.featuredTrackArtist,
            capturedAt: Date(),
            sourceApp: activity.featuredTrackSource ?? "",
            url: activity.featuredTrackURL
        )
        return WorkoutTrackDeepLink.url(for: synthesized)
    }

    /// Debug auto-play hook used by the screenshot harness (#411 follow-up).
    /// Enabled only when both `XOMFIT_AUTH_BYPASS=1` and
    /// `XOMFIT_AUTO_PLAY_FEATURED=1` are set, and only for the bypass mock
    /// "Power" featured track so we don't disturb real users' decks.
    private func shouldAutoPlay(featuredTitle: String) -> Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["XOMFIT_AUTH_BYPASS"] == "1"
            && env["XOMFIT_AUTO_PLAY_FEATURED"] == "1"
            && featuredTitle == "Power"
        #else
        return false
        #endif
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
                    HStack(spacing: Theme.Spacing.tighter) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rated \(rating) of 5 stars")
                }
            }
            .accessibilityElement(children: .combine)

            if let location = activity.location, !location.isEmpty {
                HStack(spacing: Theme.Spacing.tight) {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Duration \(formatDuration(activity.duration)), Volume \(formatVolume(activity.totalVolume)), \(activity.totalSets) sets")

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
                                .accessibilityHint("Opens full-screen viewer")
                                .accessibilityAddTraits(.isButton)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone: \(activity.title), \(activity.subtitle), badge \(activity.badge)")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activity.isNewRecord
            ? "\(activity.currentStreak) day streak, new personal record"
            : "\(activity.currentStreak) day streak, previous best \(activity.previousBest) days")
    }
}

// MARK: - Featured Soundtrack Row (#410 / soundtrack-inline-playback)

/// Compact "featured soundtrack" row used on each workout feed card. Visual
/// matches `AnthemRow` (#403) so the two stacks read as siblings — the anthem
/// is the poster's profile pick, the featured soundtrack is from this specific
/// workout.
///
/// Tap the LEFT button to play the 30s preview inline via
/// `AnthemPlaybackService` (resolves via iTunes Search when no `previewURL`).
/// The RIGHT button deep-links into the source service (Spotify / Apple Music
/// / SoundCloud) so the user can keep listening to the full track.
private struct FeaturedSoundtrackRow: View {
    let title: String
    let artist: String
    let sourceApp: String
    let deepLinkURL: URL?
    /// Debug-only — when true, triggers `playback.play(...)` on first appear
    /// so the screenshot harness can capture the mid-playback state without
    /// driving a tap on the simulator. Always `false` in Release.
    var autoPlay: Bool = false

    /// Live mirror of the playback service so `@Observable` changes flip the
    /// play/pause icon on this row. Calls still go through `.shared`. Plain
    /// `let` matches `AnthemRow` — SwiftUI observes via type tracking so
    /// `@State` would actually drop the observation (the wrapper boxes the
    /// reference and SwiftUI only watches the wrapper, not the underlying
    /// object's properties).
    private let playback = AnthemPlaybackService.shared

    /// `ProfileAnthem`-shaped wrapper around the captured track so we can hand
    /// it to `AnthemPlaybackService` (which is keyed on title/artist for the
    /// iTunes Search resolver).
    private var asAnthem: ProfileAnthem {
        ProfileAnthem(title: title, artist: artist, previewURL: nil, artworkURL: nil, appleMusicId: nil)
    }

    /// Treat "playing" as `currentlyPlayingID == this anthem`. We don't sniff
    /// AVPlayer's `timeControlStatus` here because the service sets that id
    /// AFTER `player.play()`, so by the time SwiftUI reads it the player
    /// might still be transitioning out of `.waitingToPlayAtSpecifiedRate`.
    /// The service's `stop()` nils the id, so this stays accurate.
    private var isPlaying: Bool { playback.currentlyPlayingID == asAnthem.id }
    private var isLoading: Bool { playback.isLoading(asAnthem) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            playButton

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !artist.isEmpty {
                        Text(artist)
                            .font(Theme.fontCaption2)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Text("\u{2022}")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityHidden(true)
                    }
                    if !sourceApp.isEmpty {
                        Text(sourceApp)
                            .font(Theme.fontCaption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Featured marker so the row visibly reads as a starred pick even
            // mid-playback. Hidden from VoiceOver because the row label below
            // already says "Featured track".
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            if let url = deepLinkURL {
                Button {
                    Haptics.light()
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Don't bubble taps to the parent card (which opens detail).
                .simultaneousGesture(TapGesture().onEnded {})
                .accessibilityLabel(WorkoutTrackDeepLink.label(for: sourceApp))
                .accessibilityHint("Opens this featured track in \(sourceApp).")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Featured track: \(title)\(artist.isEmpty ? "" : ", by \(artist)")")
        #if DEBUG
        .task {
            // Agent screenshot helper (#411 follow-up). Auto-kick playback
            // when the harness flag is set so a mid-playback screenshot can
            // be captured from a cold-launch script.
            if autoPlay && !playback.isPlaying(asAnthem) {
                try? await Task.sleep(for: .milliseconds(800))
                await playback.play(asAnthem)
            }
        }
        #endif
    }

    /// Inline play/pause button. Toggles `AnthemPlaybackService.shared` so only
    /// one preview plays at a time across the app.
    private var playButton: some View {
        Button {
            Haptics.light()
            Task { await playback.toggle(asAnthem) }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 28, height: 28)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.background)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.background)
                        // Optical centering — SF Symbol's play glyph sits
                        // slightly left of the geometric center.
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            // 44pt minimum touch target.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Stop tap from bubbling to the parent card (FeedItemCard wraps the
        // whole row in a tap-to-open-detail gesture).
        .simultaneousGesture(TapGesture().onEnded { })
        .accessibilityLabel(isPlaying ? "Pause featured track preview" : "Play featured track preview")
        .accessibilityHint("Plays a 30 second preview of \(title) inline.")
    }
}
