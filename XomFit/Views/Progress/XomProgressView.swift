import SwiftUI

struct XomProgressView: View {
    @State private var selectedTimeframe = 0
    let timeframes = ["Week", "Month", "3 Months", "Year"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Timeframe Picker
                        Picker("Timeframe", selection: $selectedTimeframe) {
                            ForEach(0..<timeframes.count, id: \.self) { i in
                                Text(timeframes[i]).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Summary Cards
                        HStack(spacing: 12) {
                            ProgressStatCard(title: "Workouts", value: "12", change: "+3", isPositive: true)
                            ProgressStatCard(title: "Volume", value: "48.2k", change: "+12%", isPositive: true)
                            ProgressStatCard(title: "PRs", value: "4", change: "+2", isPositive: true)
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Strength Progress (Placeholder Chart)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Strength Progress")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            // Placeholder chart area
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .fill(Theme.secondaryBackground)
                                    .frame(height: 200)
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.accent.opacity(0.5))
                                    Text("Charts coming soon")
                                        .font(Theme.fontCaption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Volume by Muscle Group
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Volume by Muscle Group")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            VStack(spacing: 8) {
                                MuscleVolumeBar(muscle: "Chest", percentage: 0.85, volume: "12,450")
                                MuscleVolumeBar(muscle: "Back", percentage: 0.75, volume: "10,800")
                                MuscleVolumeBar(muscle: "Legs", percentage: 0.65, volume: "9,200")
                                MuscleVolumeBar(muscle: "Shoulders", percentage: 0.45, volume: "6,100")
                                MuscleVolumeBar(muscle: "Arms", percentage: 0.40, volume: "5,500")
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Recent PRs
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent PRs")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            ForEach(PersonalRecord.mockPRs) { pr in
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(Theme.prGold)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pr.exerciseName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(pr.date.timeAgo)
                                            .font(Theme.fontCaption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(pr.weight.formattedWeight) × \(pr.reps)")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                        if let imp = pr.improvementString {
                                            Text(imp)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(Theme.prGold)
                                        }
                                    }
                                }
                                .cardStyle()
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                    }
                    .padding(.top, Theme.paddingSmall)
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(change)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isPositive ? Theme.accent : Theme.destructive)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

struct MuscleVolumeBar: View {
    let muscle: String
    let percentage: CGFloat
    let volume: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(volume) lbs")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.secondaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: geometry.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
