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
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: Theme.paddingSmall) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 40))
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
                                    .padding(.horizontal, Theme.paddingMedium)
                                    .padding(.vertical, 6)
                            }
                        }
                        .padding(.top, Theme.paddingSmall)
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
        HStack(spacing: Theme.paddingSmall) {
            TextField("Add a comment...", text: $newCommentText)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

            Button {
                Task { await postComment() }
            } label: {
                if isPosting {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(newCommentText.isEmpty ? Theme.textSecondary : Theme.accent)
                }
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(Theme.cardBackground)
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
        HStack(alignment: .top, spacing: Theme.paddingSmall) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 34, height: 34)
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "User")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(comment.createdAt.timeAgo)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(comment.text)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        let name = comment.user?.displayName ?? "U"
        return String(name.prefix(2)).uppercased()
    }
}
