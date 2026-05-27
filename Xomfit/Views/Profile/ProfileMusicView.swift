import SwiftUI

struct ProfileMusicView: View {
    let tracks: [AggregatedTrack]

    @State private var sourceFilter: String?

    private var sources: [String] {
        Array(Set(tracks.map(\.sourceApp))).sorted()
    }

    private var filteredTracks: [AggregatedTrack] {
        guard let filter = sourceFilter else { return tracks }
        return tracks.filter { $0.sourceApp == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if tracks.isEmpty {
                emptyState
            } else {
                filterBar
                trackList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("No listening history yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text("Tracks will appear here after workouts with music capture enabled.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(label: "All", isActive: sourceFilter == nil) {
                    sourceFilter = nil
                }
                ForEach(sources, id: \.self) { source in
                    FilterChip(label: source, isActive: sourceFilter == source) {
                        sourceFilter = source
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var trackList: some View {
        LazyVStack(spacing: Theme.Spacing.xs) {
            ForEach(filteredTracks) { track in
                TrackRow(track: track)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .black : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Theme.accent : Theme.surface)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct TrackRow: View {
    let track: AggregatedTrack

    private var sourceIcon: String {
        switch track.sourceApp {
        case "Spotify": return "music.note"
        case "Apple Music": return "music.quarternote.3"
        case "SoundCloud": return "waveform"
        default: return "music.note"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: sourceIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.xs) {
                    if let artist = track.artist, !artist.isEmpty {
                        Text(artist)
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Text("· \(track.sourceApp)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Theme.Spacing.tighter) {
                Text("\(track.playCount)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                Text(track.playCount == 1 ? "play" : "plays")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }
}
