import AVFoundation
import SwiftUI

// MARK: - TrimRange

struct TrimRange {
    var startSeconds: Double
    var endSeconds: Double

    var cmTimeRange: CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: endSeconds - startSeconds, preferredTimescale: 600)
        )
    }

    var duration: Double { endSeconds - startSeconds }
}

// MARK: - VideoTrimmer

/// Trims a recorded clip to a user-selected range and exports to a new file.
@MainActor
final class VideoTrimmer: ObservableObject {

    @Published var trimRange: TrimRange = TrimRange(startSeconds: 0, endSeconds: 15)
    @Published var totalDuration: Double = 0
    @Published var isTrimming: Bool = false
    @Published var trimError: String?
    @Published var trimmedURL: URL?

    // Thumbnail frames extracted for the scrubber
    @Published var thumbnailFrames: [UIImage] = []

    private var asset: AVURLAsset?

    // MARK: - Load

    func load(url: URL) async {
        let asset = AVURLAsset(url: url)
        self.asset = asset

        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            totalDuration = seconds
            trimRange = TrimRange(startSeconds: 0, endSeconds: min(seconds, 15))
            await extractThumbnails(asset: asset, duration: seconds)
        } catch {
            trimError = "Could not load video: \(error.localizedDescription)"
        }
    }

    // MARK: - Thumbnails for scrubber

    private func extractThumbnails(asset: AVURLAsset, duration: Double, count: Int = 8) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 80)

        let times = stride(from: 0.0, to: duration, by: duration / Double(count)).map {
            CMTime(seconds: $0, preferredTimescale: 600)
        }

        var frames: [UIImage] = []
        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append(UIImage(cgImage: cgImage))
            }
        }
        thumbnailFrames = frames
    }

    // MARK: - Trim & Export

    /// Export the trimmed clip to a new temp file.
    func trim(sourceURL: URL) async throws -> URL {
        isTrimming = true
        defer { isTrimming = false }
        trimError = nil

        let asset = AVURLAsset(url: sourceURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(asset: asset,
                                                       presetName: AVAssetExportPresetMediumQuality) else {
            throw TrimError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = trimRange.cmTimeRange
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        if let error = exportSession.error {
            self.trimError = error.localizedDescription
            throw error
        }

        trimmedURL = outputURL
        return outputURL
    }

    // MARK: - Convenience

    func clampedStart(_ value: Double) -> Double {
        max(0, min(value, trimRange.endSeconds - 1.0))
    }

    func clampedEnd(_ value: Double) -> Double {
        min(totalDuration, max(value, trimRange.startSeconds + 1.0))
    }
}

// MARK: - Errors

enum TrimError: LocalizedError {
    case exportSessionCreationFailed

    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed: return "Could not create export session for trimming."
        }
    }
}

// MARK: - TrimmerScrubberView

/// Drag-handle scrubber shown in the video trimmer sheet.
struct TrimmerScrubberView: View {
    @ObservedObject var trimmer: VideoTrimmer
    let frameWidth: CGFloat

    private var thumbWidth: CGFloat { 8 }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail strip
            HStack(spacing: 1) {
                ForEach(Array(trimmer.thumbnailFrames.enumerated()), id: \.offset) { _, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: frameWidth / CGFloat(max(trimmer.thumbnailFrames.count, 1)), height: 50)
                        .clipped()
                }
            }
            .frame(height: 50)
            .cornerRadius(6)
            .overlay(
                // Selected range highlight
                GeometryReader { geo in
                    let total = trimmer.totalDuration
                    let startX = total > 0 ? (trimmer.trimRange.startSeconds / total) * geo.size.width : 0
                    let endX = total > 0 ? (trimmer.trimRange.endSeconds / total) * geo.size.width : geo.size.width
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.accent, lineWidth: 2)
                        .frame(width: endX - startX)
                        .offset(x: startX)
                }
            )

            // Labels
            HStack {
                Text(String(format: "%.1fs", trimmer.trimRange.startSeconds))
                    .font(Theme.fontCaption)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1fs", trimmer.trimRange.endSeconds))
                    .font(Theme.fontCaption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)

            // Start / End sliders
            VStack(spacing: 8) {
                HStack {
                    Text("Start")
                        .font(Theme.fontCaption)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .leading)
                    Slider(value: Binding(
                        get: { trimmer.trimRange.startSeconds },
                        set: { trimmer.trimRange.startSeconds = trimmer.clampedStart($0) }
                    ), in: 0...trimmer.totalDuration)
                    .tint(Theme.accent)
                }
                HStack {
                    Text("End")
                        .font(Theme.fontCaption)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .leading)
                    Slider(value: Binding(
                        get: { trimmer.trimRange.endSeconds },
                        set: { trimmer.trimRange.endSeconds = trimmer.clampedEnd($0) }
                    ), in: 0...trimmer.totalDuration)
                    .tint(Theme.accent)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
}
