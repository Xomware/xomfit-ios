import SwiftUI
import AVKit

// MARK: - VideoPlayerView

/// Reusable AVPlayer view with play/pause, seek bar, and loop support.
struct VideoPlayerView: View {
    let url: URL?
    var autoPlay: Bool = true
    var looping: Bool = true
    var showControls: Bool = true

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isSeeking: Bool = false
    @State private var timeObserver: Any?

    var body: some View {
        ZStack {
            Color.black

            if let player {
                AVPlayerRepresentable(player: player)
            } else {
                Image(systemName: "video.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
            }

            if showControls && player != nil {
                controlOverlay
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
        .onChange(of: url) { _, _ in setupPlayer() }
    }

    // MARK: - Controls overlay

    private var controlOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                // Seek bar
                Slider(value: Binding(
                    get: { currentTime },
                    set: { seek(to: $0) }
                ), in: 0...max(duration, 0.01))
                .tint(Theme.accent)
                .padding(.horizontal)

                // Timestamps + Play/Pause
                HStack {
                    Text(timeString(currentTime))
                        .font(Theme.fontSmall)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }

                    Spacer()

                    Text(timeString(duration))
                        .font(Theme.fontSmall)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 12)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        teardown()
        guard let url else { return }
        let newPlayer = AVPlayer(url: url)
        player = newPlayer

        // Duration
        Task {
            let asset = AVURLAsset(url: url)
            if let dur = try? await asset.load(.duration) {
                duration = max(CMTimeGetSeconds(dur), 0)
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isSeeking else { return }
            currentTime = CMTimeGetSeconds(time)
        }

        // End-of-file loop
        if looping {
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                   object: newPlayer.currentItem,
                                                   queue: .main) { _ in
                newPlayer.seek(to: .zero)
                if autoPlay { newPlayer.play() }
            }
        }

        if autoPlay {
            newPlayer.play()
            isPlaying = true
        }
    }

    private func teardown() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
    }

    // MARK: - Actions

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func seek(to seconds: Double) {
        isSeeking = true
        currentTime = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { _ in
            isSeeking = false
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - AVPlayerRepresentable

private struct AVPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspect
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// MARK: - Inline Video Card

/// Compact inline player for use inside list/feed cards.
struct InlineVideoPlayerView: View {
    let url: URL?
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            if let url, isExpanded {
                VideoPlayerView(url: url, autoPlay: true, looping: true, showControls: true)
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(Theme.cornerRadiusSmall)
            } else {
                // Placeholder / tap to play
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color.black)
                    .aspectRatio(9/16, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Tap to play")
                                .font(Theme.fontCaption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .onTapGesture { isExpanded = true }
            }
        }
    }
}

#Preview {
    VideoPlayerView(url: nil, autoPlay: false)
        .frame(height: 300)
        .preferredColorScheme(.dark)
}
