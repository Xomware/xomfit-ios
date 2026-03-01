import SwiftUI

struct AICoachView: View {
    @StateObject private var viewModel = AICoachViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Analyzing your training...")
                            .padding(40)
                    } else {
                        // Readiness Card
                        if let readiness = viewModel.readiness {
                            ReadinessCard(readiness: readiness)
                        }
                        
                        // Insights
                        if !viewModel.insights.isEmpty {
                            insightsSection
                        }
                        
                        // Training Load
                        if let load = viewModel.trainingLoad {
                            TrainingLoadCard(load: load)
                        }
                        
                        // Volume by Muscle
                        volumeSection
                        
                        // Periodization
                        periodizationSection
                    }
                }
                .padding()
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadAll() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { viewModel.loadAll() }
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.insights) { insight in
                CoachInsightCard(insight: insight) {
                    viewModel.dismissInsight(insight)
                }
            }
        }
    }
    
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.muscleVolumes) { vol in
                    MuscleVolumeCard(volume: vol)
                }
            }
        }
    }
    
    private var periodizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("6-Week Periodization Plan")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(viewModel.periodizationPlan) { block in
                    PeriodizationBlockRow(block: block)
                }
            }
        }
    }
}

// MARK: - Readiness Card
struct ReadinessCard: View {
    let readiness: ReadinessScore
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Readiness")
                        .font(.headline)
                    Text(readiness.fatigueLevel.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness.score) / 100)
                        .stroke(readinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(readiness.score)")
                        .font(.title2)
                        .bold()
                }
            }
            
            Text(readiness.recommendation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ComponentBar(label: "Volume", value: readiness.components.recentVolume)
                ComponentBar(label: "Consistency", value: readiness.components.consistency)
                ComponentBar(label: "Recovery", value: readiness.components.recoveryDays)
                ComponentBar(label: "Momentum", value: readiness.components.prMomentum)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    var readinessColor: Color {
        switch readiness.score {
        case 75...: return .green
        case 50..<75: return .yellow
        case 25..<50: return .orange
        default: return .red
        }
    }
}

struct ComponentBar: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.3))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(height: CGFloat(value) / 100 * 40)
                    , alignment: .bottom
                )
        }
    }
}

// MARK: - Coach Insight Card
struct CoachInsightCard: View {
    let insight: CoachInsight
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insightIcon)
                .font(.title3)
                .foregroundColor(insightColor)
                .frame(width: 36, height: 36)
                .background(insightColor.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text("\(Int(insight.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(insight.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionLabel = insight.actionLabel {
                    Button(actionLabel) { onDismiss() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    var insightIcon: String {
        switch insight.type {
        case .deloadSuggestion: return "bed.double.fill"
        case .progressiveOverload: return "arrow.up.circle.fill"
        case .volumeRecommendation: return "chart.bar.fill"
        case .recoveryAlert: return "exclamationmark.triangle.fill"
        case .prOpportunity: return "star.fill"
        case .exerciseSwap: return "arrow.2.squarepath"
        }
    }
    
    var insightColor: Color {
        switch insight.priority {
        case 1: return .red
        case 2: return .blue
        default: return .gray
        }
    }
}

// MARK: - Training Load Card
struct TrainingLoadCard: View {
    let load: TrainingLoad
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load (ACWR)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acute (7d)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(load.acute)) sets")
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("Ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", load.ratio))
                        .font(.title2)
                        .bold()
                        .foregroundColor(ratioColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Chronic (28d avg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(load.chronic)) sets")
                        .font(.title3)
                        .bold()
                }
            }
            
            Text(load.riskLevel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ratioColor.opacity(0.15))
                .foregroundColor(ratioColor)
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    var ratioColor: Color {
        switch load.ratio {
        case ..<0.8: return .blue
        case 0.8..<1.3: return .green
        case 1.3..<1.5: return .orange
        default: return .red
        }
    }
}

// MARK: - Muscle Volume Card
struct MuscleVolumeCard: View {
    let volume: MuscleGroupVolume
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(volume.muscleGroup)
                .font(.caption)
                .bold()
            
            ProgressView(value: min(volume.percentOfTarget, 1.0))
                .tint(progressColor)
            
            Text("\(volume.currentWeeklySets)/\(volume.weeklySetTarget) sets")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    var progressColor: Color {
        switch volume.percentOfTarget {
        case 0.8...: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - Periodization Block Row
struct PeriodizationBlockRow: View {
    let block: PeriodizationBlock
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("W\(block.weekNumber)")
                    .font(.caption)
                    .bold()
                Circle()
                    .fill(phaseColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(block.phase.rawValue)
                    .font(.subheadline)
                    .bold()
                Text(block.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(block.targetVolume) sets")
                    .font(.caption)
                    .bold()
                Text("\(Int(block.targetIntensity * 100))% 1RM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var phaseColor: Color {
        switch block.phase {
        case .accumulation: return .blue
        case .intensification: return .orange
        case .realization: return .red
        case .deload: return .green
        }
    }
}
