import SwiftUI

struct CommentThreadView: View {
    let post: FeedPost
    @State private var commentText = ""
    @State private var comments: [FeedPost.Comment] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Comments")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.vertical, Theme.paddingSmall)
                .background(Color.white.opacity(0.02))
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Comments list
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.paddingMedium) {
                        // Original post summary
                        HStack(spacing: Theme.paddingSmall) {
                            Circle()
                                .fill(Theme.accentColor.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Text(String(post.user.displayName.prefix(1)))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.accentColor)
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.user.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(post.workout.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(Theme.paddingSmall)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, Theme.paddingSmall)
                        
                        // Comments
                        if comments.isEmpty {
                            VStack(spacing: Theme.paddingSmall) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray)
                                Text("No comments yet")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text("Start the conversation!")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.paddingMedium)
                        } else {
                            VStack(alignment: .leading, spacing: Theme.paddingMedium) {
                                ForEach(comments) { comment in
                                    CommentRow(comment: comment)
                                }
                            }
                        }
                    }
                    .padding(Theme.paddingMedium)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Comment input
                HStack(spacing: Theme.paddingSmall) {
                    Circle()
                        .fill(Theme.accentColor.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text("D")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.accentColor)
                        }
                    
                    HStack(spacing: Theme.paddingSmall) {
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                        
                        if !commentText.isEmpty {
                            Button(action: submitComment) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.accentColor)
                            }
                        }
                    }
                }
                .padding(Theme.paddingMedium)
                .background(Color.white.opacity(0.02))
            }
            .background(Theme.background)
        }
        .onAppear {
            comments = post.comments
        }
    }
    
    private func submitComment() {
        let newComment = FeedPost.Comment(
            id: UUID().uuidString,
            user: .mock,
            text: commentText,
            createdAt: Date()
        )
        comments.insert(newComment, at: 0)
        commentText = ""
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: FeedPost.Comment
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack(alignment: .top, spacing: Theme.paddingSmall) {
                Circle()
                    .fill(Theme.accentColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(comment.user.displayName.prefix(1)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.accentColor)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.paddingSmall) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(comment.user.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("@\(comment.user.username)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        Text(comment.createdAt.timeAgoDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(nil)
                    
                    HStack(spacing: Theme.paddingMedium) {
                        Button(action: { isLiked.toggle() }) {
                            HStack(spacing: 2) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 10))
                                    .foregroundColor(isLiked ? .red : .gray)
                                Text(isLiked ? "Liked" : "Like")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Text("Reply")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(Theme.paddingSmall)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

#Preview {
    CommentThreadView(post: FeedPost.mockFeed[0])
}
