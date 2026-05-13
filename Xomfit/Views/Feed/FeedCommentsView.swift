import SwiftUI

/// Threaded comments view (#320).
/// Renders top-level comments + nested replies indented 24pt with a 'Reply' affordance.
/// Reply mode pins an "@username" prefix above the composer; an X clears it.
struct FeedCommentsView: View {
    let feedItemId: String
    let userId: String

    @State private var comments: [FeedComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isPosting = false
    /// When non-nil, the next post is a reply to this comment.
    @State private var replyingTo: FeedComment? = nil

    @FocusState private var composerFocused: Bool

    /// Indent applied to nested replies.
    private static let replyIndent: CGFloat = 24

    /// #319: hard cap on comment length (Twitter-style 280). Composer enforces
    /// this on every keystroke and shows a counter once the user crosses the
    /// soft threshold.
    private static let commentMaxLength = 280
    /// Show the live counter once the comment is longer than this. Keeps the
    /// composer chrome out of the way for short comments.
    private static let commentCounterThreshold = 200

    private var commentLength: Int { newCommentText.count }
    private var remainingChars: Int { Self.commentMaxLength - commentLength }
    private var isOverLimit: Bool { commentLength > Self.commentMaxLength }
    private var showCounter: Bool { commentLength > Self.commentCounterThreshold }

    /// Top-level comments only — replies are rendered nested under their parent.
    private var topLevelComments: [FeedComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    /// Map of parent comment id -> ordered replies (oldest first).
    private var repliesByParent: [String: [FeedComment]] {
        Dictionary(grouping: comments.filter { $0.parentCommentId != nil }) { $0.parentCommentId ?? "" }
            .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonCard(height: 60)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "bubble.right")
                            .font(Theme.fontLargeTitle)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                        Text("No comments yet")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Be the first to comment")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No comments yet. Be the first to comment.")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(topLevelComments) { comment in
                                threadView(for: comment)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, 6)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }

                replyContextBar
                commentComposer
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadComments() }
    }

    // MARK: - Thread Renderer

    @ViewBuilder
    private func threadView(for parent: FeedComment) -> some View {
        VStack(spacing: 0) {
            CommentRow(comment: parent, onReply: { startReply(to: parent) })

            // Replies — indented 24pt left of the parent.
            if let replies = repliesByParent[parent.id], !replies.isEmpty {
                VStack(spacing: 0) {
                    ForEach(replies) { reply in
                        CommentRow(comment: reply, onReply: { startReply(to: parent) })
                    }
                }
                .padding(.leading, Self.replyIndent)
            }
        }
    }

    // MARK: - Reply Context Bar

    @ViewBuilder
    private var replyContextBar: some View {
        if let replyingTo {
            HStack(spacing: Theme.Spacing.xs) {
                Text("Replying to ")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                + Text("@\(displayHandle(for: replyingTo))")
                    .font(Theme.fontSmall.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                Spacer()

                Button {
                    Haptics.light()
                    cancelReply()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cancel reply")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.tight)
            .background(Theme.surface)
            .overlay(alignment: .top) { XomDivider() }
        }
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        VStack(spacing: Theme.Spacing.tight) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField(replyingTo == nil ? "Add a comment..." : "Add a reply...", text: $newCommentText)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .strokeBorder(
                                isOverLimit ? Theme.destructive.opacity(0.6) : .clear,
                                lineWidth: 1
                            )
                    )
                    .focused($composerFocused)
                    // #319: enforce the 280-char cap on every keystroke. Paste
                    // longer text and it gets trimmed back to the cap.
                    .onChange(of: newCommentText) { _, newValue in
                        if newValue.count > Self.commentMaxLength {
                            newCommentText = String(newValue.prefix(Self.commentMaxLength))
                        }
                    }

                Button {
                    Haptics.light()
                    Task { await postComment() }
                } label: {
                    if isPosting {
                        ProgressView()
                            .tint(.black)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(Theme.fontLargeTitle)
                            .foregroundStyle(newCommentText.isEmpty ? Theme.textSecondary : Theme.accent)
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPosting || isOverLimit)
                .accessibilityLabel(replyingTo == nil ? "Post comment" : "Post reply")
            }

            // #319: live counter once the comment is long enough that the cap
            // is in sight. Stays hidden for short comments so the composer
            // doesn't gain extra chrome.
            if showCounter {
                HStack {
                    Spacer()
                    Text("\(commentLength)/\(Self.commentMaxLength)")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(isOverLimit ? Theme.destructive : Theme.textSecondary)
                        .monospacedDigit()
                        .accessibilityLabel(
                            isOverLimit
                                ? "Over limit by \(commentLength - Self.commentMaxLength) characters"
                                : "\(remainingChars) characters remaining"
                        )
                }
                .padding(.trailing, Theme.Spacing.tight)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
        .animation(.easeOut(duration: 0.15), value: showCounter)
        .animation(.easeOut(duration: 0.15), value: isOverLimit)
    }

    // MARK: - Actions

    /// Resolves a user-facing handle for the reply context bar.
    /// Falls back to displayName when the username is empty (placeholder profile rows
    /// from `FeedService.buildSocialFeedItem` may be empty).
    private func displayHandle(for comment: FeedComment) -> String {
        if let username = comment.user?.username, !username.isEmpty {
            return username
        }
        return comment.user?.displayName ?? "user"
    }

    private func startReply(to comment: FeedComment) {
        Haptics.selection()
        replyingTo = comment
        composerFocused = true
    }

    private func cancelReply() {
        replyingTo = nil
    }

    private func loadComments() async {
        isLoading = true
        do {
            comments = try await FeedService.shared.fetchComments(feedItemId: feedItemId)
        } catch {
            // Non-fatal
        }
        isLoading = false
    }

    private func postComment() async {
        let text = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        // #319: defensive — UI disables Send when over the cap, but block here
        // too so any future entry point can't bypass the limit.
        guard text.count <= Self.commentMaxLength else { return }
        isPosting = true
        do {
            try await FeedService.shared.postComment(
                feedItemId: feedItemId,
                userId: userId,
                text: text,
                parentCommentId: replyingTo?.id
            )
            newCommentText = ""
            replyingTo = nil
            comments = try await FeedService.shared.fetchComments(feedItemId: feedItemId)
        } catch {
            // Non-fatal
        }
        isPosting = false
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: FeedComment
    /// Tapped when the user taps the Reply button on this row.
    let onReply: () -> Void

    /// #367: handle used in accessibility label for the profile link.
    private var profileHandle: String {
        if let username = comment.user?.username, !username.isEmpty { return username }
        return comment.user?.displayName ?? "user"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                // #367: avatar + name push the commenter's ProfileView.
                NavigationLink {
                    ProfileView(userId: comment.userId)
                        .hideTabBar()
                } label: {
                    HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                        XomAvatar(
                            name: comment.user?.displayName ?? "User",
                            size: 32
                        )

                        HStack(spacing: 6) {
                            Text(comment.user?.displayName ?? "User")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(comment.createdAt.timeAgo)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                .accessibilityLabel("View profile of @\(profileHandle)")
                .accessibilityHint("Opens this user's profile")

                Spacer()
            }
            .padding(.top, 10)

            // Body text + Reply button stay outside the profile link so taps on
            // them don't navigate. Indented to align under the name.
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Color.clear.frame(width: 32, height: 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(comment.text)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)

                    Button(action: onReply) {
                        Text("Reply")
                            .font(Theme.fontSmall.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.trailing, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reply to \(comment.user?.displayName ?? "user")")
                    .accessibilityHint("Adds a threaded reply under this comment")
                }

                Spacer()
            }
            .padding(.bottom, 10)

            XomDivider()
        }
    }
}
