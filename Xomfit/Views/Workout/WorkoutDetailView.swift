import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    summaryCard
                    exerciseList
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .hideTabBar()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: Theme.Spacing.md) {
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

                    if let location = workout.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(Theme.fontSmall)
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()

                if let rating = workout.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        }
                    }
                }
                Text(workout.durationString)
                    .font(.subheadline.weight(.bold).monospaced())
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
                                .background(Theme.surfaceSecondary)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(notes)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseCard(exercise: exercise, index: index + 1)
            }
        }
    }

    private func exerciseCard(exercise: WorkoutExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 0) {
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.sm)

                    // Set rows
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, workoutSet in
                        setRow(set: workoutSet, number: setIndex + 1)
                    }

                    // Exercise notes
                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("\(index)")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24, height: 24)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 6))

                    Text(exercise.exercise.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Text("\(exercise.sets.count) sets")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.caption2)
                            Text("PR")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.prGold)
                    }
                }
            }
            .tint(Theme.accent)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
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
                    .font(.caption2)
                    .foregroundStyle(Theme.prGold)
                    .padding(.leading, 6)
            }
        }
        .font(.subheadline.weight(.medium).monospaced())
        .padding(.vertical, 4)
        .accessibilityLabel("Set \(number): \(formatWeight(set.weight)) lbs for \(set.reps) reps\(set.isPersonalRecord ? ", personal record" : "")")
    }

    // MARK: - Helpers

    private func summaryStatView(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.body.weight(.bold))
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
