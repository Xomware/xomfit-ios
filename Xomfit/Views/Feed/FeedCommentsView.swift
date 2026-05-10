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
                            .font(.largeTitle)
                            .foregroundStyle(Theme.textSecondary)
                        Text("No comments yet")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Be the first to comment")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                    }
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
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cancel reply")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 4)
            .background(Theme.surface)
            .overlay(alignment: .top) { XomDivider() }
        }
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField(replyingTo == nil ? "Add a comment..." : "Add a reply...", text: $newCommentText)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .focused($composerFocused)

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
                        .font(.largeTitle)
                        .foregroundStyle(newCommentText.isEmpty ? Theme.textSecondary : Theme.accent)
                }
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
            .accessibilityLabel(replyingTo == nil ? "Post comment" : "Post reply")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                XomAvatar(
                    name: comment.user?.displayName ?? "User",
                    size: 32
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(comment.user?.displayName ?? "User")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(comment.createdAt.timeAgo)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Text(comment.text)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)

                    Button(action: onReply) {
                        Text("Reply")
                            .font(Theme.fontSmall.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.trailing, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reply to \(comment.user?.displayName ?? "user")")
                }

                Spacer()
            }
            .padding(.vertical, 10)

            XomDivider()
        }
    }
}
