import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.paddingMedium) {
                    summaryCard
                    exerciseList
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.vertical, Theme.paddingSmall)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: Theme.paddingMedium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.startTime.workoutDateString)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    if let endTime = workout.endTime {
                        Text(timeRangeString(start: workout.startTime, end: endTime))
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Text(workout.durationString)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 0) {
                summaryStatView(value: "\(workout.exercises.count)", label: "Exercises")
                Spacer()
                summaryStatView(value: "\(workout.totalSets)", label: "Sets")
                Spacer()
                summaryStatView(value: "\(workout.formattedVolume) lbs", label: "Volume")
                if workout.totalPRs > 0 {
                    Spacer()
                    summaryStatView(value: "\(workout.totalPRs)", label: "PRs", highlight: true)
                }
            }

            if !workout.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workout.muscleGroups, id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.secondaryBackground)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(notes)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: Theme.paddingSmall) {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseCard(exercise: exercise, index: index + 1)
            }
        }
    }

    private func exerciseCard(exercise: WorkoutExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Exercise name header
            HStack(spacing: Theme.paddingSmall) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))

                Text(exercise.exercise.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                        Text("PR")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.prGold)
                }
            }

            // Column headers
            HStack(spacing: 0) {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("REPS")
                    .frame(width: 50, alignment: .trailing)
                Text("VOL")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)

            // Set rows
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, workoutSet in
                setRow(set: workoutSet, number: setIndex + 1)
            }

            // Exercise notes
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func setRow(set: WorkoutSet, number: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(number)")
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(Theme.textSecondary)

            Text(formatWeight(set.weight))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(Theme.textPrimary)

            Text("\(set.reps)")
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(Theme.textPrimary)

            Text(formatWeight(set.volume))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(Theme.textSecondary)

            if set.isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.prGold)
                    .padding(.leading, 6)
            }
        }
        .font(.system(size: 14, weight: .medium, design: .monospaced))
        .padding(.vertical, 4)
        .accessibilityLabel("Set \(number): \(formatWeight(set.weight)) lbs for \(set.reps) reps\(set.isPersonalRecord ? ", personal record" : "")")
    }

    // MARK: - Helpers

    private func summaryStatView(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(highlight ? Theme.prGold : Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
