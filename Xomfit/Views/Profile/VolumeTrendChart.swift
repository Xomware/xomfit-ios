import Charts
import SwiftUI

/// Bar chart showing weekly volume buckets covering the last 30 days.
/// The most recent bucket renders in `Theme.accent`; prior buckets fade to half opacity.
struct VolumeTrendChart: View {
    let buckets: [ProfileViewModel.VolumeBucket]

    /// Display unit for axis + accessibility labels. Stored values stay lbs.
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    /// Percent change vs. previous bucket. Returns nil when there is no prior data
    /// or the prior bucket has zero volume (avoids divide-by-zero / infinite jumps).
    private var percentChange: Double? {
        guard buckets.count >= 2 else { return nil }
        let previous = buckets[buckets.count - 2].volume
        let current = buckets[buckets.count - 1].volume
        guard previous > 0 else { return nil }
        return (current - previous) / previous
    }

    private var changeCaption: (text: String, color: Color)? {
        guard let pct = percentChange else { return nil }
        if pct > 0.001 {
            return (String(format: "+%.0f%% vs last week", pct * 100), Theme.accent)
        } else if pct < -0.001 {
            return (String(format: "%.0f%% vs last week", pct * 100), Theme.destructive)
        } else {
            return ("0% vs last week", Theme.textSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let caption = changeCaption {
                Text(caption.text)
                    .font(Theme.fontSmall)
                    .foregroundStyle(caption.color)
                    .accessibilityLabel("Volume change: \(caption.text)")
            }

            Chart(buckets) { bucket in
                let displayVolume = bucket.volume * weightUnit.multiplierFromLbs
                BarMark(
                    x: .value("Week", Self.dayMonthFormatter.string(from: bucket.weekStart)),
                    y: .value("Volume", displayVolume)
                )
                .foregroundStyle(barColor(for: bucket))
                .cornerRadius(4)
                .accessibilityLabel(Self.dayMonthFormatter.string(from: bucket.weekStart))
                .accessibilityValue("\(formattedVolume(displayVolume)) \(weightUnit.accessibilityName)")
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formattedVolume(v))
                                .font(Theme.fontCaption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Volume trend chart")
            .accessibilityValue(chartSummary)
        }
    }

    /// One-line summary of the chart for VoiceOver — current week volume + change.
    private var chartSummary: String {
        guard let latest = buckets.last else { return "No volume data yet" }
        let displayVolume = latest.volume * weightUnit.multiplierFromLbs
        var parts = ["Latest week \(formattedVolume(displayVolume)) \(weightUnit.accessibilityName)"]
        if let caption = changeCaption {
            parts.append(caption.text)
        }
        return parts.joined(separator: ", ")
    }

    private func barColor(for bucket: ProfileViewModel.VolumeBucket) -> Color {
        if bucket.id == buckets.last?.id {
            return Theme.accent
        }
        return Theme.accent.opacity(0.5)
    }

    private func formattedVolume(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }
}

#Preview {
    VolumeTrendChart(
        buckets: [
            .init(weekStart: Date().addingTimeInterval(-86400 * 28), volume: 12_500),
            .init(weekStart: Date().addingTimeInterval(-86400 * 21), volume: 9_800),
            .init(weekStart: Date().addingTimeInterval(-86400 * 14), volume: 14_200),
            .init(weekStart: Date().addingTimeInterval(-86400 * 7), volume: 16_400)
        ]
    )
    .padding()
    .background(Theme.background)
}
