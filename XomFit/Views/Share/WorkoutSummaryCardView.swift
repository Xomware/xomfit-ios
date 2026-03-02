import SwiftUI

// MARK: - Card Theme
enum CardTheme: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case fire = "Fire"
    case chill = "Chill"

    var id: String { rawValue }

    var gradientColors: [Color] {
        switch self {
        case .default:
            return [Color(hex: "1a1a2e"), Color(hex: "0a2a3e")]
        case .fire:
            return [Color(hex: "1a1a2e"), Color(hex: "3a1a0a")]
        case .chill:
            return [Color(hex: "1a1a2e"), Color(hex: "1a0a3a")]
        }
    }

    var accentColor: Color {
        switch self {
        case .default: return Color(hex: "00b4d8")
        case .fire: return Color(hex: "ff6b35")
        case .chill: return Color(hex: "8b5cf6")
        }
    }

    var icon: String {
        switch self {
        case .default: return "bolt.fill"
        case .fire: return "flame.fill"
        case .chill: return "snowflake"
        }
    }
}

// MARK: - Completed Workout Model
struct CompletedWorkout {
    let name: String
    let date: Date
    let duration: TimeInterval
    let exercises: [ExerciseSummary]
    let totalVolume: Double
    let totalSets: Int
    let totalReps: Int
    let newPRs: [PRRecord]
    let caloriesBurned: Int?
    let userName: String
}

struct ExerciseSummary {
    let name: String
    let bestSetWeight: Double
    let bestSetReps: Int
    let setCount: Int
}

struct PRRecord {
    let exerciseName: String
    let weight: Double
    let previousBest: Double?
}

// MARK: - Card View
struct WorkoutSummaryCardView: View {
    let workout: CompletedWorkout
    let theme: CardTheme

    static let cardWidth: CGFloat = 400
    static let cardHeight: CGFloat = 711

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: theme.gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                // Workout Complete label
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(theme.accentColor)
                        Text("WORKOUT")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }
                    Text("COMPLETE")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                }

                Spacer().frame(height: 24)

                // Duration
                Text(formatDuration(workout.duration))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(theme.accentColor)

                Spacer().frame(height: 28)

                // Exercise list (top 3)
                exerciseListSection
                    .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                // PR badge
                if !workout.newPRs.isEmpty {
                    prBadge
                        .padding(.horizontal, 28)
                    Spacer().frame(height: 16)
                }

                Spacer()

                // Stats bar
                statsBar
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Footer
                footerSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.accentColor)
                Text("XomFit")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Exercise List
    private var exerciseListSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(workout.exercises.prefix(3).enumerated()), id: \.offset) { _, exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text("\(exercise.setCount)×\(exercise.bestSetReps) @ \(exercise.bestSetWeight.formattedWeight) lbs")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.accentColor.opacity(0.9))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - PR Badge
    private var prBadge: some View {
        HStack(spacing: 6) {
            Text("🏆")
                .font(.system(size: 18))
            Text("\(workout.newPRs.count) NEW PR\(workout.newPRs.count == 1 ? "" : "s")!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "FFD700"))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(Color(hex: "FFD700").opacity(0.15))
        .cornerRadius(20)
    }

    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack {
            statItem(value: formatVolume(workout.totalVolume), label: "Volume")
            Spacer()
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 32)
            Spacer()
            statItem(value: "\(workout.totalSets)", label: "Sets")
            if let cals = workout.caloriesBurned {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 32)
                Spacer()
                statItem(value: "\(cals)", label: "Cal")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            Text("@\(workout.userName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text("xomfit")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.accentColor.opacity(0.5))
        }
    }

    // MARK: - Helpers
    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        Self.formatDuration(interval)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return "\(Int(volume)) lbs"
    }
}

// MARK: - Preview
#Preview {
    WorkoutSummaryCardView(
        workout: CompletedWorkout(
            name: "Push Day",
            date: Date(),
            duration: 4980,
            exercises: [
                ExerciseSummary(name: "Squat", bestSetWeight: 225, bestSetReps: 5, setCount: 5),
                ExerciseSummary(name: "Bench Press", bestSetWeight: 185, bestSetReps: 5, setCount: 4),
                ExerciseSummary(name: "Deadlift", bestSetWeight: 275, bestSetReps: 5, setCount: 3),
            ],
            totalVolume: 24500,
            totalSets: 18,
            totalReps: 72,
            newPRs: [
                PRRecord(exerciseName: "Squat", weight: 225, previousBest: 215),
                PRRecord(exerciseName: "Bench Press", weight: 185, previousBest: 175),
            ],
            caloriesBurned: 340,
            userName: "domgiordano"
        ),
        theme: .fire
    )
    .previewLayout(.sizeThatFits)
    .background(Color.black)
}
