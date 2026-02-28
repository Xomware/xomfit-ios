import SwiftUI

struct EstimatedOneRMChart: View {
    let data: [OneRMTrendDataPoint]
    let exerciseName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName ?? "Estimated 1RM Trends")
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
                TrendLineChartView(data: data)
                    .frame(height: 200)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.cornerRadius)
                
                // Statistics
                HStack(spacing: 16) {
                    StatBox(
                        label: "Current 1RM",
                        value: String(format: "%.0f lbs", data.last?.estimatedOneRM ?? 0)
                    )
                    StatBox(
                        label: "Peak 1RM",
                        value: String(format: "%.0f lbs", data.max(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0)
                    )
                    if data.count > 1 {
                        let improvement = (data.last?.estimatedOneRM ?? 0) - (data.first?.estimatedOneRM ?? 0)
                        StatBox(
                            label: "Gain",
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

// MARK: - Trend Line Chart View
struct TrendLineChartView: View {
    let data: [OneRMTrendDataPoint]
    
    var scaledData: [CGFloat] {
        guard !data.isEmpty else { return [] }
        let min = data.min(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0
        let max = data.max(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0
        let range = max - min
        
        return data.map { point in
            range > 0 ? CGFloat((point.estimatedOneRM - min) / range) : 0.5
        }
    }
    
    var averageOneRM: Double {
        guard !data.isEmpty else { return 0 }
        return data.reduce(0) { $0 + $1.estimatedOneRM } / Double(data.count)
    }
    
    var trendDirection: String {
        guard data.count > 1 else { return "→" }
        let improvement = (data.last?.estimatedOneRM ?? 0) - (data.first?.estimatedOneRM ?? 0)
        if improvement > 0 { return "↑" }
        if improvement < 0 { return "↓" }
        return "→"
    }
    
    var body: some View {
        Canvas { context in
            let width = context.size.width
            let height = context.size.height
            let padding: CGFloat = 20
            
            let chartWidth = width - (padding * 2)
            let chartHeight = height - (padding * 2)
            
            // Draw grid lines and average line
            var gridPath = Path()
            let averageScaled = CGFloat((averageOneRM - (data.min(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0)) / 
                                        (data.max(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0) - 
                                        (data.min(by: { $0.estimatedOneRM < $1.estimatedOneRM })?.estimatedOneRM ?? 0))
            
            for i in 0...4 {
                let y = padding + (CGFloat(i) / 4.0) * chartHeight
                gridPath.move(to: CGPoint(x: padding, y: y))
                gridPath.addLine(to: CGPoint(x: width - padding, y: y))
            }
            
            context.stroke(gridPath, with: .color(Theme.textSecondary.opacity(0.1)), lineWidth: 1)
            
            // Draw trend line
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
            
            context.stroke(dataPath, with: .color(Theme.accent), lineWidth: 2.5)
            
            // Draw data points
            for (index, scaledValue) in scaledData.enumerated() {
                let x = padding + (CGFloat(index) / CGFloat(scaledData.count - 1)) * chartWidth
                let y = padding + (1 - scaledValue) * chartHeight
                
                let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                context.fill(Circle().path(in: rect), with: .color(Theme.accent))
                context.stroke(Circle().path(in: rect), with: .color(Theme.background), lineWidth: 2)
            }
        }
    }
}

#Preview {
    let mockData = [
        OneRMTrendDataPoint(date: Date().addingTimeInterval(-604800), estimatedOneRM: 300),
        OneRMTrendDataPoint(date: Date().addingTimeInterval(-518400), estimatedOneRM: 305),
        OneRMTrendDataPoint(date: Date().addingTimeInterval(-432000), estimatedOneRM: 303),
        OneRMTrendDataPoint(date: Date().addingTimeInterval(-345600), estimatedOneRM: 310),
        OneRMTrendDataPoint(date: Date().addingTimeInterval(-259200), estimatedOneRM: 315),
        OneRMTrendDataPoint(date: Date(), estimatedOneRM: 320),
    ]
    
    EstimatedOneRMChart(data: mockData, exerciseName: "Squat")
        .background(Theme.background)
        .padding()
}
