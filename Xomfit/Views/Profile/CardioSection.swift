import SwiftUI

/// Cardio on the profile — what the lifter's watch recorded, sitting alongside
/// what they lifted.
///
/// Own profile only, and that isn't a design choice: `cardio_sessions` carries
/// `FOR ALL USING (user_id = auth.uid())`, so another user's sessions are
/// unreadable by the database. The caller still gates on `userId` so the section
/// doesn't render an empty shell on someone else's profile.
///
/// Sessions come from `CardioService.shared`, which the Cardio tab also reads —
/// one cache, so the two screens can't disagree about what was imported.
struct CardioSection: View {
    let userId: String

    @State private var service = CardioService.shared
    @State private var hasLoaded = false

    /// Rolling window for the headline numbers. A lifetime total stops moving
    /// and stops meaning anything; 30 days answers "am I still doing this".
    private static let windowDays = 30
    private static let recentLimit = 3

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: Date()) ?? .distantPast
    }

    private var recentWindow: [CardioSession] {
        service.sessions.filter { $0.startTime >= windowStart }
    }

    private var totalMiles: Double {
        recentWindow.compactMap(\.distanceMiles).reduce(0, +)
    }

    private var totalSeconds: Double {
        recentWindow.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
            } else if service.sessions.isEmpty {
                emptyState
            } else {
                rollup
                ForEach(service.sessions.prefix(Self.recentLimit)) { session in
                    sessionRow(session)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .cardStyle()
        .task {
            guard !hasLoaded else { return }
            await service.fetchSessions(userId: userId)
            hasLoaded = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Cardio")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if !service.sessions.isEmpty {
                NavigationLink {
                    CardioListView(userId: userId)
                } label: {
                    Text("See all")
                        .font(Theme.fontCaption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Rollup

    private var rollup: some View {
        HStack(spacing: Theme.Spacing.sm) {
            rollupTile("Sessions", "\(recentWindow.count)")
            // Distance is meaningless for lifters who only log rows or stair
            // climbs, so it hides rather than showing a confident 0.0 mi.
            if totalMiles > 0 {
                rollupTile("Miles", String(format: "%.1f", totalMiles))
            }
            rollupTile("Time", timeString(totalSeconds))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Last \(Self.windowDays) days")
    }

    private func rollupTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.fontTitle3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label.uppercased())
                .font(Theme.fontMetricLabel)
                .kerning(0.6)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Rows

    private func sessionRow(_ session: CardioSession) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: session.modality.icon)
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.modality.displayName)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                // Distance and pace are both optional — a treadmill session with
                // no distance still deserves a readable subtitle.
                Text(detailLine(session))
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.startTime, format: .dateTime.month(.abbreviated).day())
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                if session.isImported {
                    // Worth distinguishing: an imported session is the watch's
                    // record, not something logged here.
                    Image(systemName: "heart.text.square")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityLabel("Imported from Health")
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func detailLine(_ session: CardioSession) -> String {
        var parts: [String] = [session.durationDisplay]
        if let miles = session.distanceMiles, miles > 0 {
            parts.append(String(format: "%.2f mi", miles))
        }
        if let pace = session.paceDisplay {
            parts.append(pace)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("No cardio logged yet.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
            Text("Runs and rides from your watch land here once Health import is on.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
