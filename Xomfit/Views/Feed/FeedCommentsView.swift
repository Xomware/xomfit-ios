import SwiftUI

struct FeedCommentsView: View {
    let feedItemId: String
    let userId: String

    @State private var comments: [FeedComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isPosting = false

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
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, 6)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }

                commentComposer
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadComments() }
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Add a comment...", text: $newCommentText)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

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
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
    }

    // MARK: - Actions

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
                text: text
            )
            newCommentText = ""
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
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)

            XomDivider()
        }
    }
}
