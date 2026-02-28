import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedPreset: DateRangePreset = .lastMonth
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Analytics")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Track your strength and fitness progress")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Date Range Filter
                        DateRangeFilter(
                            selectedPreset: $selectedPreset,
                            startDate: $viewModel.selectedStartDate,
                            endDate: $viewModel.selectedEndDate
                        )
                        .onChange(of: viewModel.selectedStartDate) { _, _ in
                            // Trigger analytics update
                        }
                        .onChange(of: viewModel.selectedEndDate) { _, _ in
                            // Trigger analytics update
                        }
                        
                        // Summary Stats
                        SummaryStatsSection(viewModel: viewModel)
                        
                        // Weight Progression Chart
                        if !viewModel.weightProgressionData.isEmpty {
                            WeightProgressionChart(
                                data: viewModel.weightProgressionData,
                                exerciseName: "Weight Progression"
                            )
                            .padding(.horizontal, Theme.paddingMedium)
                        }
                        
                        // Estimated 1RM Trends
                        if !viewModel.estimatedOneRMTrends.isEmpty {
                            EstimatedOneRMChart(
                                data: viewModel.estimatedOneRMTrends,
                                exerciseName: "Estimated 1RM"
                            )
                            .padding(.horizontal, Theme.paddingMedium)
                        }
                        
                        // Volume by Muscle Group
                        if !viewModel.volumeByMuscleGroup.isEmpty {
                            VolumeByMuscleGroupChart(data: viewModel.volumeByMuscleGroup)
                                .padding(.horizontal, Theme.paddingMedium)
                        }
                        
                        // Workout Frequency
                        if !viewModel.workoutFrequency.isEmpty {
                            WorkoutFrequencyChart(data: viewModel.workoutFrequency)
                                .padding(.horizontal, Theme.paddingMedium)
                        }
                        
                        // Empty state
                        if viewModel.weightProgressionData.isEmpty &&
                           viewModel.volumeByMuscleGroup.isEmpty &&
                           viewModel.workoutFrequency.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.accent.opacity(0.5))
                                
                                Text("No Analytics Data")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("Complete some workouts to see your progress")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        }
                    }
                    .padding(.vertical, Theme.paddingMedium)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Summary Stats Section
struct SummaryStatsSection: View {
    let viewModel: AnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.paddingMedium)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Workouts",
                        value: "\(viewModel.totalWorkouts)",
                        icon: "dumbbell.fill",
                        color: .blue
                    )
                    
                    SummaryCard(
                        title: "Volume",
                        value: viewModel.totalVolume >= 1000 ? 
                            String(format: "%.1fk", viewModel.totalVolume / 1000) :
                            String(format: "%.0f", viewModel.totalVolume),
                        icon: "scalemass.fill",
                        color: .green
                    )
                }
                
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Sets",
                        value: "\(viewModel.totalSets)",
                        icon: "rectangle.fill",
                        color: .orange
                    )
                    
                    SummaryCard(
                        title: "Avg Duration",
                        value: formatDuration(viewModel.averageWorkoutDuration),
                        icon: "timer.circle.fill",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal, Theme.paddingMedium)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    AnalyticsView()
}
