//
//  XomfitWidget.swift
//  XomfitWidget
//
//  Home screen widgets: streak, weekly stats, recent PR.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Keys (duplicated from main app — keep in sync)

private enum WidgetKeys {
    static let streak = "widget_streak"
    static let weeklyVolume = "widget_weekly_volume"
    static let weeklyWorkouts = "widget_weekly_workouts"
    static let lastWorkoutName = "widget_last_workout_name"
    static let lastWorkoutDate = "widget_last_workout_date"
    static let recentPR = "widget_recent_pr"
    static let lastUpdated = "widget_last_updated"
}

private let suiteName = "group.com.xomware.xomfit"
private let accentGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
private let darkBg = Color(red: 0.039, green: 0.039, blue: 0.059)

// MARK: - Timeline Entry

struct XomfitEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let weeklyVolume: Double
    let weeklyWorkouts: Int
    let lastWorkoutName: String?
    let lastWorkoutDate: Date?
    let recentPR: String?
}

// MARK: - Timeline Provider

struct XomfitProvider: TimelineProvider {
    func placeholder(in context: Context) -> XomfitEntry {
        XomfitEntry(
            date: Date(),
            streak: 7,
            weeklyVolume: 24500,
            weeklyWorkouts: 4,
            lastWorkoutName: "Push Day",
            lastWorkoutDate: Date().addingTimeInterval(-3600),
            recentPR: "Bench Press 225 lbs"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (XomfitEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<XomfitEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> XomfitEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        return XomfitEntry(
            date: Date(),
            streak: defaults?.integer(forKey: WidgetKeys.streak) ?? 0,
            weeklyVolume: defaults?.double(forKey: WidgetKeys.weeklyVolume) ?? 0,
            weeklyWorkouts: defaults?.integer(forKey: WidgetKeys.weeklyWorkouts) ?? 0,
            lastWorkoutName: defaults?.string(forKey: WidgetKeys.lastWorkoutName),
            lastWorkoutDate: defaults?.object(forKey: WidgetKeys.lastWorkoutDate) as? Date,
            recentPR: defaults?.string(forKey: WidgetKeys.recentPR)
        )
    }
}

// MARK: - Small Widget (Streak)

struct StreakWidgetView: View {
    let entry: XomfitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Spacer()
            }

            Spacer()

            Text("\(entry.streak)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("day streak")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .containerBackground(darkBg, for: .widget)
    }
}

// MARK: - Medium Widget (Weekly Stats)

struct WeeklyStatsWidgetView: View {
    let entry: XomfitEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: streak
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(entry.streak)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Divider()
                .background(.white.opacity(0.2))

            // Middle: workouts this week
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .foregroundStyle(accentGreen)
                Spacer()
                Text("\(entry.weeklyWorkouts)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Divider()
                .background(.white.opacity(0.2))

            // Right: volume
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "scalemass.fill")
                    .font(.title3)
                    .foregroundStyle(accentGreen)
                Spacer()
                Text(formatVolume(entry.weeklyVolume))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("volume")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .containerBackground(darkBg, for: .widget)
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return "\(Int(v))"
    }
}

// MARK: - Large Widget (Full Summary)

struct FullSummaryWidgetView: View {
    let entry: XomfitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(accentGreen)
                Text("XomFit")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Stats row
            HStack(spacing: 0) {
                statBlock(value: "\(entry.streak)", label: "Streak", icon: "flame.fill", color: .orange)
                Spacer()
                statBlock(value: "\(entry.weeklyWorkouts)", label: "Workouts", icon: "figure.strengthtraining.traditional", color: accentGreen)
                Spacer()
                statBlock(value: formatVolume(entry.weeklyVolume), label: "Volume", icon: "scalemass.fill", color: accentGreen)
            }

            Divider().background(.white.opacity(0.15))

            // Last workout
            if let name = entry.lastWorkoutName {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Last: \(name)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    if let date = entry.lastWorkoutDate {
                        Text(date, style: .relative)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // Recent PR
            if let pr = entry.recentPR {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                    Text("PR: \(pr)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(darkBg, for: .widget)
    }

    private func statBlock(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return "\(Int(v))"
    }
}

// MARK: - Widget Definition

struct XomfitWidget: Widget {
    let kind: String = "XomfitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: XomfitProvider()) { entry in
            XomfitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("XomFit Stats")
        .description("Track your streak, weekly volume, and recent PRs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Multi-size rendering

struct XomfitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: XomfitEntry

    var body: some View {
        switch family {
        case .systemSmall:
            StreakWidgetView(entry: entry)
        case .systemMedium:
            WeeklyStatsWidgetView(entry: entry)
        case .systemLarge:
            FullSummaryWidgetView(entry: entry)
        default:
            StreakWidgetView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    XomfitWidget()
} timeline: {
    XomfitEntry(date: .now, streak: 12, weeklyVolume: 34500, weeklyWorkouts: 5, lastWorkoutName: "Push Day", lastWorkoutDate: Date().addingTimeInterval(-3600), recentPR: "Bench 225 lbs")
}

#Preview("Medium", as: .systemMedium) {
    XomfitWidget()
} timeline: {
    XomfitEntry(date: .now, streak: 12, weeklyVolume: 34500, weeklyWorkouts: 5, lastWorkoutName: "Push Day", lastWorkoutDate: Date().addingTimeInterval(-3600), recentPR: "Bench 225 lbs")
}

#Preview("Large", as: .systemLarge) {
    XomfitWidget()
} timeline: {
    XomfitEntry(date: .now, streak: 12, weeklyVolume: 34500, weeklyWorkouts: 5, lastWorkoutName: "Push Day", lastWorkoutDate: Date().addingTimeInterval(-3600), recentPR: "Bench 225 lbs")
}
