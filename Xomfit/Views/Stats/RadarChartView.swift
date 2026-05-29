import SwiftUI

/// Radar / spider chart visualizing muscle-group training balance.
///
/// Accepts normalized values in `0.0...1.0` keyed by axis name. The number of
/// axes drives the polygon shape — 6 keys render a hexagon, 8 an octagon, etc.
/// Pass `axisOrder` to control the clockwise perimeter order; otherwise keys
/// are sorted alphabetically for a stable layout.
struct RadarChartView: View {
    let data: [String: Double]
    let axisOrder: [String]

    /// Concentric grid rings drawn behind the data polygon.
    private let ringFractions: [CGFloat] = [0.25, 0.5, 0.75, 1.0]

    init(data: [String: Double], axisOrder: [String]? = nil) {
        self.data = data
        self.axisOrder = axisOrder ?? data.keys.sorted()
    }

    private var axes: [String] { axisOrder }

    var body: some View {
        GeometryReader { proxy in
            // Reserve a margin so axis labels don't clip the card edge.
            let labelInset: CGFloat = 34
            let size = min(proxy.size.width, proxy.size.height)
            let radius = max(size / 2 - labelInset, 8)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let count = max(axes.count, 1)

            ZStack {
                gridRings(center: center, radius: radius, count: count)
                spokes(center: center, radius: radius, count: count)
                dataPolygon(center: center, radius: radius, count: count)
                vertexDots(center: center, radius: radius, count: count)
                labels(center: center, radius: radius, count: count)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Muscle balance radar chart")
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: - Geometry

    /// Point on a circle for axis `index`, scaled by `fraction` of `radius`.
    /// Axis 0 sits at the top (12 o'clock); subsequent axes go clockwise.
    private func point(index: Int, count: Int, center: CGPoint, radius: CGFloat, fraction: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + (2 * .pi * CGFloat(index) / CGFloat(count))
        return CGPoint(
            x: center.x + cos(angle) * radius * fraction,
            y: center.y + sin(angle) * radius * fraction
        )
    }

    // MARK: - Layers

    private func gridRings(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(Array(ringFractions.enumerated()), id: \.offset) { _, fraction in
            polygonPath(center: center, radius: radius, count: count, fraction: fraction)
                .stroke(Theme.hairline, lineWidth: 0.5)
        }
    }

    private func spokes(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(0..<count, id: \.self) { index in
            Path { path in
                path.move(to: center)
                path.addLine(to: point(index: index, count: count, center: center, radius: radius, fraction: 1.0))
            }
            .stroke(Theme.hairline, lineWidth: 0.5)
        }
    }

    private func dataPolygon(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        let path = Path { path in
            for index in 0..<count {
                let value = CGFloat(max(0, min(1, data[axes[index]] ?? 0)))
                let pt = point(index: index, count: count, center: center, radius: radius, fraction: value)
                if index == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
        return ZStack {
            path.fill(Theme.accent.opacity(0.3))
            path.stroke(Theme.accent, lineWidth: 2)
        }
    }

    private func vertexDots(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(0..<count, id: \.self) { index in
            let value = CGFloat(max(0, min(1, data[axes[index]] ?? 0)))
            let pt = point(index: index, count: count, center: center, radius: radius, fraction: value)
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .position(pt)
        }
    }

    private func labels(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(0..<count, id: \.self) { index in
            let pt = point(index: index, count: count, center: center, radius: radius, fraction: 1.16)
            Text(axes[index])
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize()
                .position(pt)
        }
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, count: Int, fraction: CGFloat) -> Path {
        Path { path in
            for index in 0..<count {
                let pt = point(index: index, count: count, center: center, radius: radius, fraction: fraction)
                if index == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        axes.map { name in
            let pct = Int((max(0, min(1, data[name] ?? 0))) * 100)
            return "\(name) \(pct) percent"
        }
        .joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    RadarChartView(
        data: [
            "Chest": 0.9,
            "Shoulders": 0.6,
            "Arms": 0.45,
            "Core": 0.3,
            "Legs": 0.75,
            "Back": 0.85
        ],
        axisOrder: ["Chest", "Shoulders", "Arms", "Core", "Legs", "Back"]
    )
    .frame(height: 280)
    .padding()
    .background(Theme.background)
}
