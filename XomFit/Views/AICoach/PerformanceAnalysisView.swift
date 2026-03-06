import SwiftUI

struct PerformanceAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    
    let analysis: PerformanceAnalysis
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                TabView(selection: $selectedTab) {
                    // Volume Analysis
                    volumeTab
                        .tag(0)
                    
                    // Muscle Groups
                    muscleGroupsTab
                        .tag(1)
                    
                    // Imbalances
                    imbalancesTab
                        .tag(2)
                    
                    // Estimated Maxes
                    maxesTab
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle("Performance Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Tabs
    
    private var volumeTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VolumeAnalysisCard(analysis: analysis)
                StrengthProgressCard(analysis: analysis)
                Spacer()
            }
            .padding(16)
        }
    }
    
    private var muscleGroupsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Muscle Group Breakdown")
                    .font(.system(.headline, design: .default)).bold()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                VStack(spacing: 12) {
                    ForEach(analysis.muscleGroupsSorted) { group in
                        MuscleGroupCard(group: group)
                    }
                }
                .padding(16)
                
                Spacer()
            }
        }
    }
    
    private var imbalancesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if analysis.imbalances.isEmpty {
                    VStack(spacing: 12) {
                        Text("✅")
                            .font(.system(size: 40))
                        Text("Well Balanced!")
                            .font(.system(.headline, design: .default)).bold()
                        Text("Your muscle groups are training at balanced frequency.")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                } else {
                    Text("Muscle Imbalances")
                        .font(.system(.headline, design: .default)).bold()
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    VStack(spacing: 12) {
                        ForEach(analysis.imbalances) { imbalance in
                            ImbalanceCard(imbalance: imbalance)
                        }
                    }
                    .padding(16)
                }
                
                Spacer()
            }
        }
    }
    
    private var maxesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estimated 1-Rep Maxes")
                    .font(.system(.headline, design: .default)).bold()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                if analysis.estimatedMaxes.isEmpty {
                    VStack(spacing: 12) {
                        Text("📊")
                            .font(.system(size: 40))
                        Text("Not Enough Data")
                            .font(.system(.headline, design: .default)).bold()
                        Text("Log more workouts for estimated maxes")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        ForEach(analysis.estimatedMaxes) { max in
                            EstimatedMaxCard(max: max)
                        }
                    }
                    .padding(16)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Supporting Cards

struct VolumeAnalysisCard: View {
    let analysis: PerformanceAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volume Progression")
                    .font(.system(.headline, design: .default)).bold()
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 14))
                    Text(analysis.volumeProgression.trend.rawValue.uppercased())
                        .font(.system(.caption, design: .default)).bold()
                }
                .foregroundColor(trendColor)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Last Month", value: "\(Int(analysis.volumeProgression.totalLastMonth)) lbs")
                StatRow(label: "Last 3 Months", value: "\(Int(analysis.volumeProgression.totalLastThreeMonths)) lbs")
            }
            
            Text(analysis.volumeProgression.recommendation)
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var trendIcon: String {
        switch analysis.volumeProgression.trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch analysis.volumeProgression.trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .yellow
        }
    }
}

struct StrengthProgressCard: View {
    let analysis: PerformanceAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Strength Progress")
                    .font(.system(.headline, design: .default)).bold()
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 14))
                    Text(analysis.strengthProgression.trend.rawValue.uppercased())
                        .font(.system(.caption, design: .default)).bold()
                }
                .foregroundColor(trendColor)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "PRs This Month", value: "\(analysis.strengthProgression.prsSinceDate)")
                StatRow(label: "Avg RPE", value: String(format: "%.1f", analysis.strengthProgression.averageRPELastMonth))
                StatRow(label: "High Intensity Sets", value: "\(analysis.strengthProgression.rpe9PlusCount)")
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var trendIcon: String {
        switch analysis.strengthProgression.trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch analysis.strengthProgression.trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .yellow
        }
    }
}

struct MuscleGroupCard: View {
    let group: PerformanceAnalysis.MuscleGroupAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.muscleGroup.icon)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.muscleGroup.displayName)
                        .font(.system(.subheadline, design: .default)).bold()
                    Text(group.frequency.displayName)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(group.status.icon)
                        .font(.system(size: 16))
                    Text(group.status.displayName)
                        .font(.system(.caption, design: .default)).bold()
                }
            }
            
            ProgressView(value: group.relativeVolume, total: 1.0)
                .tint(.green)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ImbalanceCard: View {
    let imbalance: PerformanceAnalysis.Imbalance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(imbalance.muscleGroup1.icon)
                        Text(imbalance.muscleGroup1.displayName)
                            .font(.system(.caption, design: .default)).bold()
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("vs")
                            .font(.system(.caption, design: .default))
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(imbalance.muscleGroup2.icon)
                        Text(imbalance.muscleGroup2.displayName)
                            .font(.system(.caption, design: .default)).bold()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", imbalance.volumeRatio))
                        .font(.system(.headline, design: .default)).bold()
                    Text("ratio")
                        .font(.system(.caption2, design: .default))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(imbalance.recommendation)
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(severityBackground)
        .cornerRadius(8)
    }
    
    private var severityBackground: Color {
        switch imbalance.severity {
        case .minor: return Color.yellow.opacity(0.1)
        case .moderate: return Color.orange.opacity(0.1)
        case .severe: return Color.red.opacity(0.1)
        }
    }
}

struct EstimatedMaxCard: View {
    let max: PerformanceAnalysis.ExerciseMax
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(max.exerciseName)
                    .font(.system(.subheadline, design: .default)).bold()
                Text("Based on \(max.basedOnSets) set\(max.basedOnSets == 1 ? "" : "s")")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f lbs", max.estimatedMax))
                    .font(.system(.headline, design: .default)).bold()
                    .foregroundColor(.green)
                
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                    Text("\(Int(max.confidence * 100))%")
                        .font(.system(.caption2, design: .default))
                }
                .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .default)).bold()
        }
    }
}

#Preview {
    PerformanceAnalysisView(analysis: PerformanceAnalysis(
        muscleGroupsAnalysis: [],
        volumeProgression: PerformanceAnalysis.VolumeProgress(
            totalLastMonth: 25000,
            totalLastThreeMonths: 70000,
            trend: .up,
            recommendation: "Keep going!"
        ),
        strengthProgression: PerformanceAnalysis.StrengthProgress(
            prsSinceDate: 3,
            averageRPELastMonth: 7.5,
            rpe9PlusCount: 8,
            trend: .up
        ),
        imbalances: [],
        estimatedMaxes: []
    ))
}
