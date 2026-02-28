import SwiftUI

struct AICoachView: View {
    @StateObject var viewModel: AICoachViewModel
    @State private var showAnalysis = false
    @State private var showSettings = false
    
    var user: User
    var workouts: [Workout]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        headerSection
                        
                        // Analysis Score Card
                        if let analysis = viewModel.performanceAnalysis {
                            analysisScoreCard(analysis)
                        }
                        
                        // Top Recommendation
                        if let topRec = viewModel.topRecommendation {
                            featuredRecommendationCard(topRec)
                        } else if viewModel.hasRecommendations {
                            emptyStateCard
                        } else if !viewModel.isLoading && viewModel.errorMessage == nil {
                            noRecommendationsCard
                        }
                        
                        // Additional Recommendations
                        if viewModel.recommendations.count > 1 {
                            moreRecommendationsSection
                        }
                        
                        // Insights Section
                        if let analysis = viewModel.performanceAnalysis {
                            insightsSection(analysis)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    viewModel.loadRecommendations(userId: user.id, workouts: workouts, userStats: user.stats)
                    viewModel.analyzePerformance(userId: user.id, workouts: workouts)
                }
                
                // Loading State
                if viewModel.isLoading {
                    loadingOverlay
                }
                
                // Error State
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(.green)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAnalysis = true }) {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showAnalysis) {
                if let analysis = viewModel.performanceAnalysis {
                    PerformanceAnalysisView(analysis: analysis)
                }
            }
            .sheet(isPresented: $showSettings) {
                AICoachSettingsView(viewModel: viewModel)
            }
        }
        .onAppear {
            if workouts.count > 0 {
                viewModel.loadRecommendations(userId: user.id, workouts: workouts, userStats: user.stats)
                viewModel.analyzePerformance(userId: user.id, workouts: workouts)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(user.displayName)")
                        .font(.system(.headline, design: .default))
                        .foregroundColor(.primary)
                    
                    Text("AI Coach is analyzing your performance")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func analysisScoreCard(_ analysis: PerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Performance")
                    .font(.system(.subheadline, design: .default)).bold()
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(analysis.overallScore * 100))%")
                        .font(.system(.headline, design: .default)).bold()
                        .foregroundColor(.green)
                    Text("Score")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: analysis.overallScore)
                .tint(.green)
            
            HStack(spacing: 12) {
                StatBadge(
                    title: "Volume",
                    value: analysis.volumeProgression.trend.rawValue.uppercased(),
                    icon: "📈"
                )
                
                StatBadge(
                    title: "Strength",
                    value: String(analysis.strengthProgression.prsSinceDate),
                    icon: "💪"
                )
                
                StatBadge(
                    title: "Imbalances",
                    value: String(analysis.imbalanceCount),
                    icon: "⚖️"
                )
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func featuredRecommendationCard(_ rec: AIRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(rec.displayIcon)
                            .font(.system(size: 20))
                        Text(rec.displayTitle)
                            .font(.system(.headline, design: .default)).bold()
                    }
                    
                    Text(rec.reasoning)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(rec.confidencePercentage)%")
                            .font(.system(.caption, design: .default)).bold()
                    }
                    .foregroundColor(rec.confidenceColor)
                }
            }
            
            Divider()
            
            // Recommendation details
            if let exercise = rec.exercise {
                exerciseRecommendationDetail(exercise)
            } else if let program = rec.program {
                programRecommendationDetail(program)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: { viewModel.acceptRecommendation(rec) }) {
                    Label("Accept", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Button(action: { viewModel.dismissRecommendation(rec) }) {
                    Label("Skip", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(.systemGray4))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func exerciseRecommendationDetail(_ exercise: ExerciseRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.exercise.name)
                .font(.system(.subheadline, design: .default)).bold()
            
            HStack(spacing: 16) {
                DetailBadge(label: "Reps", value: "\(exercise.reps.min)-\(exercise.reps.max)")
                DetailBadge(label: "Sets", value: "\(exercise.sets)")
                DetailBadge(label: "Rest", value: "\(exercise.restSeconds)s")
            }
        }
    }
    
    private func programRecommendationDetail(_ program: ProgramRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                DetailBadge(label: "Days/Week", value: "\(program.estimatedDaysPerWeek)")
                DetailBadge(label: "Duration", value: "\(program.estimatedDurationWeeks)w")
            }
            
            Text("Focus: \(program.focusAreas.map { $0.displayName }.joined(separator: ", "))")
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
        }
    }
    
    private var moreRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other Suggestions")
                .font(.system(.subheadline, design: .default)).bold()
            
            VStack(spacing: 8) {
                ForEach(viewModel.recommendations.dropFirst()) { rec in
                    NavigationLink(value: rec) {
                        HStack {
                            Text(rec.displayIcon)
                                .font(.system(size: 16))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.displayTitle)
                                    .font(.system(.caption, design: .default)).bold()
                                    .lineLimit(1)
                                Text(rec.reasoning)
                                    .font(.system(.caption2, design: .default))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                Text("\(rec.confidencePercentage)%")
                                    .font(.system(.caption2, design: .default))
                            }
                            .foregroundColor(rec.confidenceColor)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func insightsSection(_ analysis: PerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.system(.subheadline, design: .default)).bold()
            
            // Weak Muscle Groups
            if !analysis.weakMuscleGroups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Underdeveloped Areas")
                        .font(.system(.caption, design: .default)).bold()
                        .foregroundColor(.orange)
                    
                    ForEach(analysis.weakMuscleGroups) { group in
                        HStack {
                            Text(group.muscleGroup.icon)
                            Text(group.muscleGroup.displayName)
                                .font(.system(.caption, design: .default))
                            Spacer()
                            Text(group.frequency.displayName)
                                .font(.system(.caption, design: .default))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemOrange).opacity(0.1))
                .cornerRadius(6)
            }
            
            // Imbalances
            if !analysis.imbalances.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Muscle Imbalances")
                        .font(.system(.caption, design: .default)).bold()
                        .foregroundColor(.yellow)
                    
                    ForEach(analysis.imbalances.prefix(3)) { imbalance in
                        Text("\(imbalance.muscleGroup1.displayName) vs \(imbalance.muscleGroup2.displayName): \(String(format: "%.1f", imbalance.volumeRatio))x")
                            .font(.system(.caption2, design: .default))
                    }
                }
                .padding(8)
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Text("😴")
                .font(.system(size: 40))
            Text("All Caught Up!")
                .font(.system(.headline, design: .default)).bold()
            Text("No new recommendations right now. Keep up the great work!")
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var noRecommendationsCard: some View {
        VStack(spacing: 12) {
            Text("📊")
                .font(.system(size: 40))
            Text("Not Enough Data")
                .font(.system(.headline, design: .default)).bold()
            Text("Log more workouts for personalized recommendations")
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Analyzing your training...")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func errorBanner(_ error: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(.caption, design: .default))
                Spacer()
                Button(action: { viewModel.errorMessage = nil }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                }
            }
            .padding(12)
            .background(Color(.systemRed).opacity(0.1))
            .cornerRadius(8)
            .padding(16)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 16))
            Text(value)
                .font(.system(.caption, design: .default)).bold()
                .lineLimit(1)
            Text(title)
                .font(.system(.caption2, design: .default))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemWhite))
        .cornerRadius(6)
    }
}

struct DetailBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .default)).bold()
            Text(label)
                .font(.system(.caption2, design: .default))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemWhite))
        .cornerRadius(6)
    }
}

#Preview {
    AICoachView(
        viewModel: AICoachViewModel(),
        user: .mock,
        workouts: [.mock]
    )
}
