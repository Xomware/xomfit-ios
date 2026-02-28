import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: PRViewModel
    @Binding var isPresented: Bool
    @State private var selectedExercise = "Bench Press"
    
    private let exerciseOptions = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Exercise Picker
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exerciseOptions, id: \.self) { exercise in
                        Text(exercise).tag(exercise)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Leaderboard List
                ScrollView {
                    VStack(spacing: 12) {
                        let leaderboard = viewModel.getLeaderboardForExercise(selectedExercise)
                        
                        if leaderboard.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No leaderboard data yet")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(leaderboard.enumerated()), id: \.element.user.id) { index, item in
                                leaderboardRowView(
                                    rank: index + 1,
                                    user: item.user,
                                    pr: item.pr
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func leaderboardRowView(rank: Int, user: User, pr: PersonalRecord) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            VStack {
                if rank <= 3 {
                    Image(systemName: medalImage(for: rank))
                        .font(.system(size: 18))
                        .foregroundColor(medalColor(for: rank))
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .center)
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // PR info
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(pr.weight.formattedWeight)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("×\(pr.reps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func medalImage(for rank: Int) -> String {
        switch rank {
        case 1:
            return "medal.fill"
        case 2:
            return "medal"
        case 3:
            return "medal"
        default:
            return ""
        }
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1:
            return .yellow
        case 2:
            return Color(.systemGray)
        case 3:
            return Color(red: 0.8, green: 0.6, blue: 0.4)
        default:
            return .clear
        }
    }
}

#Preview {
    LeaderboardView(
        viewModel: PRViewModel(),
        isPresented: .constant(true)
    )
}
