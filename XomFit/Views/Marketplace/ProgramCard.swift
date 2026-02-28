import SwiftUI

// MARK: - Program Card (grid tile)

struct ProgramCard: View {
    let program: WorkoutProgram
    var isImported: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                DifficultyBadge(difficulty: program.difficulty)
                Spacer()
                if program.isFeatured {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.warning)
                        .font(.caption)
                }
                if isImported {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.accent)
                        .font(.caption)
                }
            }

            // Title
            Text(program.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Creator
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(Theme.textSecondary)
                    .font(.caption2)
                Text(program.creatorName)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Stats row
            HStack(spacing: 12) {
                StatPill(icon: "calendar", value: "\(program.daysPerWeek)d/wk")
                StatPill(icon: "clock", value: "\(program.durationWeeks)wk")
                Spacer()
                RatingView(rating: program.rating, count: program.reviewCount)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 150)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(
                    isImported ? Theme.accent.opacity(0.4) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: ProgramDifficulty

    var color: Color {
        Color(hex: difficulty == .beginner ? "34C759" :
              difficulty == .intermediate ? "FF9500" :
              difficulty == .advanced ? "FF3B30" : "AF52DE")
    }

    var body: some View {
        Text(difficulty.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Rating View

struct RatingView: View {
    let rating: Double
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.warning)
            Text(String(format: "%.1f", rating))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("(\(count))")
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Featured Card (wider horizontal card)

struct FeaturedProgramCard: View {
    let program: WorkoutProgram
    var isImported: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DifficultyBadge(difficulty: program.difficulty)
                Spacer()
                Image(systemName: "star.fill")
                    .foregroundColor(Theme.warning)
                    .font(.caption)
            }

            Text(program.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            Text(program.description)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.creatorName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.accent)
                    Text("\(program.daysPerWeek) days/wk · \(program.durationWeeks) weeks")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                RatingView(rating: program.rating, count: program.reviewCount)
            }
        }
        .padding(16)
        .frame(width: 280, height: 170)
        .background(
            LinearGradient(
                colors: [Theme.cardBackground, Theme.secondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    HStack {
        ProgramCard(program: WorkoutProgram.mockPrograms[0], isImported: true)
        ProgramCard(program: WorkoutProgram.mockPrograms[1])
    }
    .padding()
    .background(Theme.background)
}
