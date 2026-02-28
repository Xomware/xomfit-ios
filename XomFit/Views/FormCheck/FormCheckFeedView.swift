import SwiftUI

// MARK: - FormCheckFeedViewModel

@MainActor
final class FormCheckFeedViewModel: ObservableObject {
    @Published var videos: [FormCheckVideo] = []
    @Published var myVideos: [FormCheckVideo] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTab: FeedTab = .friends

    enum FeedTab: String, CaseIterable {
        case friends = "Friends"
        case mine = "My Videos"
    }

    private let uploadService = VideoUploadService.shared

    func loadFeed() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let friendVideos = uploadService.fetchFriendVideos()
            async let myClips = uploadService.fetchMyVideos(userId: "current-user")
            videos = try await friendVideos
            myVideos = try await myClips
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleLike(video: FormCheckVideo) {
        func toggle(in list: inout [FormCheckVideo]) {
            guard let idx = list.firstIndex(where: { $0.id == video.id }) else { return }
            list[idx].isLiked.toggle()
            list[idx].likes += list[idx].isLiked ? 1 : -1
        }
        toggle(in: &videos)
        toggle(in: &myVideos)
    }

    func addComment(to videoId: String, text: String) {
        let comment = FormCheckVideo.VideoComment(
            id: UUID().uuidString,
            user: .mock,
            text: text,
            createdAt: Date()
        )
        func insert(in list: inout [FormCheckVideo]) {
            guard let idx = list.firstIndex(where: { $0.id == videoId }) else { return }
            list[idx].comments.insert(comment, at: 0)
        }
        insert(in: &videos)
        insert(in: &myVideos)
    }

    func updateVisibility(_ video: FormCheckVideo, to visibility: FormCheckVideo.VideoVisibility) {
        func update(in list: inout [FormCheckVideo]) {
            guard let idx = list.firstIndex(where: { $0.id == video.id }) else { return }
            list[idx].visibility = visibility
            list[idx].isPublic = visibility == .public
        }
        update(in: &videos)
        update(in: &myVideos)
    }
}

// MARK: - FormCheckFeedView

struct FormCheckFeedView: View {
    @StateObject private var viewModel = FormCheckFeedViewModel()
    @State private var selectedVideo: FormCheckVideo?
    @State private var showComments = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab picker
                    Picker("Feed", selection: $viewModel.selectedTab) {
                        ForEach(FormCheckFeedViewModel.FeedTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(Theme.paddingMedium)

                    // Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Theme.accent)
                        Spacer()
                    } else if let error = viewModel.error {
                        ErrorStateView(message: error) {
                            Task { await viewModel.loadFeed() }
                        }
                    } else {
                        let displayedVideos = viewModel.selectedTab == .friends
                            ? viewModel.videos : viewModel.myVideos

                        if displayedVideos.isEmpty {
                            EmptyFormCheckView(tab: viewModel.selectedTab)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: Theme.paddingMedium) {
                                    ForEach(displayedVideos) { video in
                                        FormCheckVideoCard(
                                            video: video,
                                            onLike: { viewModel.toggleLike(video: video) },
                                            onComment: {
                                                selectedVideo = video
                                                showComments = true
                                            },
                                            onVisibilityChange: { vis in
                                                viewModel.updateVisibility(video, to: vis)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, Theme.paddingMedium)
                                .padding(.bottom, Theme.paddingLarge)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Form Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await viewModel.loadFeed() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showComments) {
                if let video = selectedVideo {
                    FormCheckCommentSheet(
                        video: video,
                        onSubmit: { text in viewModel.addComment(to: video.id, text: text) }
                    )
                }
            }
            .task { await viewModel.loadFeed() }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - FormCheckVideoCard

struct FormCheckVideoCard: View {
    let video: FormCheckVideo
    var onLike: () -> Void
    var onComment: () -> Void
    var onVisibilityChange: (FormCheckVideo.VideoVisibility) -> Void

    @State private var showPlayer = false
    @State private var showVisibilityMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Theme.paddingSmall) {
                // Avatar
                Circle()
                    .fill(Theme.accent.opacity(0.25))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text(String((video.user?.displayName ?? "?").prefix(1)))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.user?.displayName ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(video.createdAt.timeAgoDisplay)
                        .font(Theme.fontSmall)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Visibility badge + menu (own videos only)
                VisibilityBadge(visibility: video.visibility)

                Menu {
                    ForEach([FormCheckVideo.VideoVisibility.private,
                             .friends, .public], id: \.self) { vis in
                        Button(vis.displayName) { onVisibilityChange(vis) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(6)
                }
            }
            .padding(Theme.paddingMedium)

            // Video area
            ZStack {
                Color.black

                if showPlayer {
                    VideoPlayerView(url: video.videoRemoteURL, autoPlay: true, looping: true)
                        .aspectRatio(9/16, contentMode: .fit)
                } else {
                    videoPlaceholder
                }
            }
            .aspectRatio(9/16, contentMode: .fit)
            .cornerRadius(0)

            // Exercise info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.exerciseName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(video.displaySet)
                        .font(Theme.fontCaption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(String(format: "%.1f\"", video.durationSeconds))
                    .font(Theme.fontCaption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, Theme.paddingSmall)

            Divider().background(Color.white.opacity(0.08))

            // Action row
            HStack(spacing: Theme.paddingLarge) {
                // Like
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: video.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(video.isLiked ? .red : .gray)
                        Text("\(video.likes)")
                            .font(Theme.fontCaption)
                            .foregroundColor(.gray)
                    }
                }

                // Comment
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.gray)
                        Text("\(video.comments.count)")
                            .font(Theme.fontCaption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, Theme.paddingSmall)
        }
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private var videoPlaceholder: some View {
        ZStack {
            Color.black.opacity(0.9)
            VStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.85))
                Text("Tap to play")
                    .font(Theme.fontCaption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .onTapGesture { showPlayer = true }
    }
}

// MARK: - Visibility Badge

struct VisibilityBadge: View {
    let visibility: FormCheckVideo.VideoVisibility

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: visibility.iconName)
                .font(.system(size: 9))
            Text(visibility.displayName)
                .font(Theme.fontSmall)
        }
        .foregroundColor(visibility.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(visibility.color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - FormCheckCommentSheet

struct FormCheckCommentSheet: View {
    let video: FormCheckVideo
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var localComments: [FormCheckVideo.VideoComment] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video mini-player
                VideoPlayerView(url: video.videoRemoteURL, autoPlay: false, looping: false, showControls: true)
                    .frame(height: 180)
                    .background(Color.black)

                Divider().background(Color.white.opacity(0.1))

                // Comments list
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                        if localComments.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "bubble.left")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                    Text("No comments yet — leave form feedback!")
                                        .font(Theme.fontCaption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            .padding(Theme.paddingLarge)
                        } else {
                            ForEach(localComments) { comment in
                                VideoCommentRow(comment: comment)
                            }
                        }
                    }
                    .padding(Theme.paddingMedium)
                }

                Divider().background(Color.white.opacity(0.1))

                // Input bar
                HStack(spacing: Theme.paddingSmall) {
                    TextField("Leave form feedback…", text: $commentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        .tint(Theme.accent)

                    if !commentText.isEmpty {
                        Button(action: submitComment) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(Theme.accent)
                                .font(.system(size: 18))
                        }
                    }
                }
                .padding(Theme.paddingMedium)
                .background(Theme.cardBackground)
            }
            .background(Theme.background)
            .navigationTitle("\(video.exerciseName) · \(video.displaySet)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { localComments = video.comments }
    }

    private func submitComment() {
        guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let comment = FormCheckVideo.VideoComment(
            id: UUID().uuidString,
            user: .mock,
            text: commentText,
            createdAt: Date()
        )
        localComments.insert(comment, at: 0)
        onSubmit(commentText)
        commentText = ""
    }
}

// MARK: - VideoCommentRow

struct VideoCommentRow: View {
    let comment: FormCheckVideo.VideoComment

    var body: some View {
        HStack(alignment: .top, spacing: Theme.paddingSmall) {
            Circle()
                .fill(Theme.accent.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(comment.user.displayName.prefix(1)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(comment.user.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(comment.createdAt.timeAgoDisplay)
                        .font(Theme.fontSmall)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Text(comment.text)
                    .font(Theme.fontCaption)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(Theme.paddingSmall)
        .background(Color.white.opacity(0.04))
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Empty State

struct EmptyFormCheckView: View {
    let tab: FormCheckFeedViewModel.FeedTab

    var body: some View {
        VStack(spacing: Theme.paddingMedium) {
            Spacer()
            Image(systemName: "video.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            Text(tab == .friends ? "No form check videos yet" : "You haven't recorded any clips")
                .font(Theme.fontHeadline)
                .foregroundColor(.white)
            Text(tab == .friends
                 ? "When friends share their form checks, they'll appear here."
                 : "Tap the camera icon on a set during a workout to record.")
                .font(Theme.fontCaption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingLarge)
            Spacer()
        }
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.paddingMedium) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.destructive)
            Text("Something went wrong")
                .font(Theme.fontHeadline)
                .foregroundColor(.white)
            Text(message)
                .font(Theme.fontCaption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingLarge)
            Button("Try Again", action: onRetry)
                .foregroundColor(Theme.accent)
            Spacer()
        }
    }
}

// MARK: - Visibility helpers

extension FormCheckVideo.VideoVisibility {
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .friends: return "Friends"
        case .public: return "Public"
        }
    }

    var iconName: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .public: return "globe"
        }
    }

    var color: Color {
        switch self {
        case .private: return .gray
        case .friends: return Theme.accent
        case .public: return .blue
        }
    }
}

#Preview {
    FormCheckFeedView()
}
