import SwiftUI

struct WeightProgressionChart: View {
    let data: [WeightProgressionDataPoint]
    let exerciseName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName ?? "Weight Progression")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if data.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.accent.opacity(0.5))
                        Text("No data available")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .frame(height: 200)
                .background(Theme.secondaryBackground)
                .cornerRadius(Theme.cornerRadius)
            } else {
                ChartView(data: data)
                    .frame(height: 200)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.cornerRadius)
                
                // Statistics
                HStack(spacing: 16) {
                    StatBox(
                        label: "Current",
                        value: String(format: "%.0f lbs", data.last?.weight ?? 0)
                    )
                    StatBox(
                        label: "Peak",
                        value: String(format: "%.0f lbs", data.max(by: { $0.weight < $1.weight })?.weight ?? 0)
                    )
                    if data.count > 1 {
                        let improvement = (data.last?.weight ?? 0) - (data.first?.weight ?? 0)
                        StatBox(
                            label: "Progression",
                            value: String(format: "%+.0f lbs", improvement),
                            isPositive: improvement >= 0
                        )
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Custom Chart View
struct ChartView: View {
    let data: [WeightProgressionDataPoint]
    
    var scaledData: [CGFloat] {
        guard !data.isEmpty else { return [] }
        let min = data.min(by: { $0.weight < $1.weight })?.weight ?? 0
        let max = data.max(by: { $0.weight < $1.weight })?.weight ?? 0
        let range = max - min
        
        return data.map { point in
            range > 0 ? CGFloat((point.weight - min) / range) : 0.5
        }
    }
    
    var body: some View {
        Canvas { context in
            let width = context.size.width
            let height = context.size.height
            let padding: CGFloat = 20
            
            let chartWidth = width - (padding * 2)
            let chartHeight = height - (padding * 2)
            
            // Draw grid lines
            var gridPath = Path()
            for i in 0...4 {
                let y = padding + (CGFloat(i) / 4.0) * chartHeight
                gridPath.move(to: CGPoint(x: padding, y: y))
                gridPath.addLine(to: CGPoint(x: width - padding, y: y))
            }
            context.stroke(gridPath, with: .color(Theme.textSecondary.opacity(0.1)), lineWidth: 1)
            
            // Draw data line
            guard scaledData.count > 0 else { return }
            
            var dataPath = Path()
            for (index, scaledValue) in scaledData.enumerated() {
                let x = padding + (CGFloat(index) / CGFloat(scaledData.count - 1)) * chartWidth
                let y = padding + (1 - scaledValue) * chartHeight
                
                if index == 0 {
                    dataPath.move(to: CGPoint(x: x, y: y))
                } else {
                    dataPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(dataPath, with: .color(Theme.accent), lineWidth: 2)
            
            // Draw data points
            for (index, scaledValue) in scaledData.enumerated() {
                let x = padding + (CGFloat(index) / CGFloat(scaledData.count - 1)) * chartWidth
                let y = padding + (1 - scaledValue) * chartHeight
                
                let rect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                context.fill(Circle().path(in: rect), with: .color(Theme.accent))
            }
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let label: String
    let value: String
    let isPositive: Bool?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: 4) {
                if let isPositive = isPositive {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(isPositive ? .green : .red)
                }
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Theme.background)
        .cornerRadius(8)
    }
}

#Preview {
    let mockData = [
        WeightProgressionDataPoint(date: Date().addingTimeInterval(-604800), weight: 225),
        WeightProgressionDataPoint(date: Date().addingTimeInterval(-518400), weight: 230),
        WeightProgressionDataPoint(date: Date().addingTimeInterval(-432000), weight: 228),
        WeightProgressionDataPoint(date: Date().addingTimeInterval(-345600), weight: 235),
        WeightProgressionDataPoint(date: Date().addingTimeInterval(-259200), weight: 240),
        WeightProgressionDataPoint(date: Date(), weight: 245),
    ]
    
    WeightProgressionChart(data: mockData, exerciseName: "Bench Press")
        .background(Theme.background)
        .padding()
}
