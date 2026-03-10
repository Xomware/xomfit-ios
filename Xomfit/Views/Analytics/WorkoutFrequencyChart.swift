import SwiftUI

struct WorkoutFrequencyChart: View {
    let data: [WorkoutFrequencyDataPoint]
    
    var maxWorkouts: Int {
        data.max(by: { $0.count < $1.count })?.count ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Frequency")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if data.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
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
                HeatmapView(data: data, maxWorkouts: maxWorkouts)
                    .frame(height: 200)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.cornerRadius)
                
                // Stats
                HStack(spacing: 16) {
                    StatBox(label: "Workouts", value: "\(data.filter { $0.count > 0 }.count) days")
                    StatBox(label: "Total", value: "\(data.reduce(0) { $0 + $1.count })")
                    StatBox(label: "Avg/Week", value: String(format: "%.1f", Double(data.reduce(0) { $0 + $1.count }) / Double(max(1, data.count / 7))))
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Heatmap View
struct HeatmapView: View {
    let data: [WorkoutFrequencyDataPoint]
    let maxWorkouts: Int
    
    var weeks: [[WorkoutFrequencyDataPoint]] {
        let calendar = Calendar.current
        var weeks: [[WorkoutFrequencyDataPoint]] = []
        var currentWeek: [WorkoutFrequencyDataPoint] = []
        
        for dataPoint in data {
            let weekday = calendar.component(.weekday, from: dataPoint.date)
            
            if !currentWeek.isEmpty && weekday == 1 && currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            
            currentWeek.append(dataPoint)
        }
        
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<weeks.count, id: \.self) { weekIndex in
                        VStack(spacing: 4) {
                            ForEach(0..<weeks[weekIndex].count, id: \.self) { dayIndex in
                                let dataPoint = weeks[weekIndex][dayIndex]
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForWorkoutCount(dataPoint.count))
                                    .frame(height: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
                .padding(12)
            }
            
            // Color legend
            HStack(spacing: 12) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 4) {
                    ForEach([0, 1, 2, 3], id: \.self) { count in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForWorkoutCount(count))
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    private func colorForWorkoutCount(_ count: Int) -> Color {
        if count == 0 {
            return Theme.secondaryBackground
        } else if count == 1 {
            return Theme.accent.opacity(0.3)
        } else if count == 2 {
            return Theme.accent.opacity(0.6)
        } else {
            return Theme.accent
        }
    }
}

#Preview {
    WorkoutFrequencyChart(data: {
        var data: [WorkoutFrequencyDataPoint] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date().addingTimeInterval(-30 * 24 * 3600))

        while currentDate <= Date() {
            let randomCount = Int.random(in: 0...3)
            data.append(WorkoutFrequencyDataPoint(date: currentDate, count: randomCount))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return data
    }())
    .background(Theme.background)
    .padding()
}
