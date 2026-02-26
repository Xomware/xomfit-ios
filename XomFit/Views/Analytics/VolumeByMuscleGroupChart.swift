import SwiftUI

struct VolumeByMuscleGroupChart: View {
    let data: [MuscleGroupVolume]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume by Muscle Group")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if data.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.accent.opacity(0.5))
                        Text("No data available")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .frame(height: 250)
                .background(Theme.secondaryBackground)
                .cornerRadius(Theme.cornerRadius)
            } else {
                BarChartView(data: data)
                    .frame(height: 250)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.cornerRadius)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Bar Chart View
struct BarChartView: View {
    let data: [MuscleGroupVolume]
    
    var maxVolume: Double {
        data.max(by: { $0.volume < $1.volume })?.volume ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<data.count, id: \.self) { index in
                        VStack(spacing: 8) {
                            // Bar
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Theme.accent, Theme.accent.opacity(0.6)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: CGFloat(data[index].volume / maxVolume) * 150)
                            }
                            .frame(height: 150)
                            
                            // Label
                            VStack(spacing: 4) {
                                Image(systemName: data[index].muscleGroup.icon)
                                    .font(.caption)
                                    .foregroundColor(Theme.accent)
                                
                                Text(data[index].muscleGroup.displayName)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 40)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            
            // Legend
            HStack(spacing: 12) {
                ForEach(data.prefix(3), id: \.muscleGroup) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.muscleGroup.displayName)
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(String(format: "%.0f lbs", item.volume))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    let mockData = [
        MuscleGroupVolume(muscleGroup: .chest, volume: 12500),
        MuscleGroupVolume(muscleGroup: .back, volume: 14200),
        MuscleGroupVolume(muscleGroup: .shoulders, volume: 8900),
        MuscleGroupVolume(muscleGroup: .triceps, volume: 7500),
        MuscleGroupVolume(muscleGroup: .biceps, volume: 6800),
        MuscleGroupVolume(muscleGroup: .quads, volume: 15000),
    ]
    
    VolumeByMuscleGroupChart(data: mockData)
        .background(Theme.background)
        .padding()
}
