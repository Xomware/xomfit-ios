import SwiftUI

/// Compact one-line "anthem" row with a play/pause button, artwork (if any),
/// and title + artist. Used in both the feed card (`FeedItemCard`) and the
/// profile header (`ProfileHeaderView`). (#403)
///
/// State is owned by `AnthemPlaybackService.shared` — a single source of truth
/// across the app so only one anthem plays at a time and a tap on any instance
/// of the row reflects the current playback state everywhere.
struct AnthemRow: View {
    let anthem: ProfileAnthem
    /// Visual variant. `.feed` is a tight inline row, `.profile` adds a touch
    /// more breathing room because it lives in a larger header card.
    var style: Style = .feed

    private let playback = AnthemPlaybackService.shared

    enum Style {
        case feed
        case profile
    }

    private var isPlaying: Bool { playback.isPlaying(anthem) }
    private var isLoading: Bool { playback.isLoading(anthem) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            playButton

            artworkThumbnail

            VStack(alignment: .leading, spacing: 1) {
                Text(anthem.title)
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(anthem.artist)
                    .font(Theme.fontCaption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Tiny "anthem" affordance so the row is self-explaining when the
            // user is scrolling past it. Hidden on the smallest dynamic-type
            // sizes to keep the row from wrapping.
            Image(systemName: "music.note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, style == .profile ? Theme.Spacing.sm : Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.surfaceElevated.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Anthem: \(anthem.title) by \(anthem.artist)")
        .accessibilityHint(isPlaying ? "Double tap to pause preview" : "Double tap to play 30 second preview")
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            Haptics.light()
            Task { await playback.toggle(anthem) }
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
            // 44pt minimum touch target (#403 + .claude/rules/ios.md).
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Stop tap from bubbling to the surrounding card (FeedItemCard wraps
        // the whole row in a tap-to-open-detail gesture).
        .simultaneousGesture(TapGesture().onEnded { })
        .accessibilityLabel(isPlaying ? "Pause anthem preview" : "Play anthem preview")
    }

    // MARK: - Artwork Thumbnail

    @ViewBuilder
    private var artworkThumbnail: some View {
        if let urlString = anthem.artworkURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderArtwork
                default:
                    placeholderArtwork
                        .overlay(ProgressView().scaleEffect(0.5))
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(.rect(cornerRadius: 4))
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.surface)
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        AnthemRow(
            anthem: ProfileAnthem(title: "Power", artist: "Kanye West"),
            style: .feed
        )
        AnthemRow(
            anthem: ProfileAnthem(
                title: "Till I Collapse",
                artist: "Eminem",
                previewURL: nil,
                artworkURL: nil
            ),
            style: .profile
        )
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
