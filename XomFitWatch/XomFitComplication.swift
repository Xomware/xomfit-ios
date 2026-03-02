import SwiftUI
import WidgetKit

/// Watch complication showing today's workout count.
struct XomFitComplication: Widget {
    let kind = "XomFitComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: XomFitTimelineProvider()) { entry in
            XomFitComplicationView(entry: entry)
        }
        .configurationDisplayName("XomFit")
        .description("Today's workout status")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

// MARK: - Timeline

struct XomFitTimelineEntry: TimelineEntry {
    let date: Date
    let workoutCount: Int
    let isRestDay: Bool
}

struct XomFitTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> XomFitTimelineEntry {
        XomFitTimelineEntry(date: .now, workoutCount: 0, isRestDay: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (XomFitTimelineEntry) -> Void) {
        completion(XomFitTimelineEntry(date: .now, workoutCount: 1, isRestDay: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<XomFitTimelineEntry>) -> Void) {
        // Refresh every hour
        let entry = XomFitTimelineEntry(date: .now, workoutCount: 0, isRestDay: false)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Views

struct XomFitComplicationView: View {
    let entry: XomFitTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                    Text(entry.isRestDay ? "Rest" : "\(entry.workoutCount)")
                        .font(.system(.body, design: .rounded).bold())
                }
            }
        case .accessoryInline:
            if entry.isRestDay {
                Label("Rest Day", systemImage: "bed.double.fill")
            } else {
                Label("\(entry.workoutCount) workout\(entry.workoutCount == 1 ? "" : "s") today", systemImage: "figure.strengthtraining.traditional")
            }
        default:
            Text("XomFit")
        }
    }
}
