import SwiftUI

struct PRView: View {
    @StateObject private var viewModel = PRViewModel()
    @State private var selectedExercise: String?
    @State private var showLeaderboard = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // User Stats Header
                        if let stats = viewModel.currentUserStats {
                            statsCardView(stats)
                        }
                        
                        // Recent PRs Section
                        recentPRsSection
                        
                        // Exercise Timeline
                        exerciseTimelineSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                
                // Celebration overlay
                if viewModel.isShowingCelebration, let pr = viewModel.newPRNotification {
                    celebrationView(for: pr)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("Personal Records")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showLeaderboard = true }) {
                        Image(systemName: "podium.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardView(viewModel: viewModel, isPresented: $showLeaderboard)
            }
            .onAppear {
                viewModel.loadPersonalRecords()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func statsCardView(_ stats: (oneRM: Int, threeRM: Int, fiveRM: Int)) -> some View {
        VStack(spacing: 12) {
            Text("Your Top Lifts")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PRViewStatBadge(title: "1RM", value: "\(stats.oneRM)", unit: "lbs")
                PRViewStatBadge(title: "3RM", value: "\(stats.threeRM)", unit: "lbs")
                PRViewStatBadge(title: "5RM", value: "\(stats.fiveRM)", unit: "lbs")
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent PRs")
                .font(.headline)
            
            if viewModel.recentPRs.isEmpty {
                Text("No PRs yet. Keep lifting!")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recentPRs) { pr in
                        PRRowView(pr: pr)
                    }
                }
            }
        }
    }
    
    private var exerciseTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise History")
                .font(.headline)
            
            if viewModel.prsByExercise.isEmpty {
                Text("No exercises yet")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.prsByExercise.keys.sorted(), id: \.self) { exerciseName in
                        exerciseCard(exerciseName)
                    }
                }
            }
        }
    }
    
    private func exerciseCard(_ exerciseName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: exerciseDetailView(exerciseName)) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let topPR = viewModel.getTopPRForExercise(exerciseName) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top PR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(topPR.weight.formattedWeight) lbs × \(topPR.reps)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(topPR.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func exerciseDetailView(_ exerciseName: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exerciseName)
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(viewModel.getPRsForExercise(exerciseName)) { pr in
                    PRRowView(pr: pr)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func celebrationView(for pr: PersonalRecord) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .scaleEffect(viewModel.isShowingCelebration ? 1.0 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.isShowingCelebration)
            
            VStack(spacing: 8) {
                Text("New PR! 🎉")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(pr.exerciseName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(pr.weight.formattedWeight)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(pr.reps)x")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    if let improvement = pr.improvementString {
                        Divider()
                            .frame(height: 30)
                        
                        VStack(spacing: 4) {
                            Text("Improvement")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(improvement)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 8)
        )
        .padding(20)
    }
}

// MARK: - Helper Views

struct PRViewStatBadge: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct PRRowView: View {
    let pr: PersonalRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pr.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Text("\(pr.weight.formattedWeight) lbs × \(pr.reps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let improvement = pr.improvementString {
                            Text(improvement)
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Spacer()
                
                Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    PRView()
}
