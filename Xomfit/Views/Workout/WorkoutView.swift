import SwiftUI

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showingNewWorkout = false
    @State private var workoutName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Start Workout Button
                        Button(action: { showingNewWorkout = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                Text("Start Workout")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.accent)
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Quick Start Templates
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Start")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, Theme.paddingMedium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    QuickStartCard(name: "Push Day", icon: "figure.strengthtraining.traditional", muscles: "Chest, Shoulders, Triceps")
                                    QuickStartCard(name: "Pull Day", icon: "figure.rowing", muscles: "Back, Biceps")
                                    QuickStartCard(name: "Leg Day", icon: "figure.lunges", muscles: "Quads, Hamstrings, Glutes")
                                    QuickStartCard(name: "Full Body", icon: "figure.mixed.cardio", muscles: "All Muscle Groups")
                                }
                                .padding(.horizontal, Theme.paddingMedium)
                            }
                        }
                        
                        // Recent Workouts
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Workouts")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, Theme.paddingMedium)
                            
                            if viewModel.recentWorkouts.isEmpty {
                                Text("No workouts yet. Start your first one!")
                                    .font(Theme.fontBody)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, Theme.paddingMedium)
                            } else {
                                ForEach(viewModel.recentWorkouts) { workout in
                                    RecentWorkoutRow(workout: workout)
                                        .padding(.horizontal, Theme.paddingMedium)
                                }
                            }
                        }
                    }
                    .padding(.top, Theme.paddingSmall)
                }
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showingNewWorkout) {
                ActiveWorkoutView(viewModel: viewModel)
            }
        }
    }
}

struct QuickStartCard: View {
    let name: String
    let icon: String
    let muscles: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Theme.accent)
            
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text(muscles)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(width: 140, alignment: .leading)
        .cardStyle()
    }
}

struct RecentWorkoutRow: View {
    let workout: Workout
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(workout.startTime.workoutDateString)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.durationString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accent)
                Text("\(workout.totalSets) sets")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .cardStyle()
    }
}
