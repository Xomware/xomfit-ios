import SwiftUI

/// Applies the metric-label treatment: uppercase + 0.5 kerning + `.caption.weight(.semibold)` + `textSecondary`.
/// Use as a view modifier `.metricLabel()` or wrap content in `XomMetricLabel`.
struct XomMetricLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.fontMetricLabel)
            .foregroundStyle(Theme.textSecondary)
            .kerning(0.5)
    }
}

// MARK: - View Modifier

struct MetricLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.fontMetricLabel)
            .foregroundStyle(Theme.textSecondary)
            .kerning(0.5)
            .textCase(.uppercase)
    }
}

extension View {
    /// Applies uppercase + kerning + caption semibold styling for metric labels.
    func metricLabel() -> some View {
        modifier(MetricLabelModifier())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        XomMetricLabel("Total Volume")
        XomMetricLabel("Weekly Workouts")
        Text("custom text").metricLabel()
    }
    .padding()
    .background(Theme.background)
}
