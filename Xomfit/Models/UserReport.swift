import Foundation

// MARK: - UserReport
//
// Wire shape (snake_case) is decoded via `convertFromSnakeCase` on the
// shared `JSONDecoder` configured in `ReportsService`. Backend payload:
//
//   {
//     id, kind, period_start, period_end,
//     stats_json: { total_volume, session_count, avg_session_minutes,
//                   top_exercises: [{name, volume, sets}],
//                   new_prs: [{exercise, weight, reps}] },
//     recommendation_text, created_at,
//     read_at, feedback_rating, feedback_text
//   }
//
// `stats_json` decodes to `stats` because we apply `convertFromSnakeCase`
// at decode time *and* declare it as `stats` here — matched via
// `CodingKeys` overrides below.

struct UserReport: Codable, Identifiable, Hashable {
    let id: String
    let kind: ReportKind
    let periodStart: Date
    let periodEnd: Date
    let stats: Stats
    let recommendationText: String
    let createdAt: Date
    let readAt: Date?
    let feedbackRating: Int?
    let feedbackText: String?

    enum ReportKind: String, Codable, Hashable {
        case weekly
        case monthly
    }

    struct Stats: Codable, Hashable {
        let totalVolume: Double
        let sessionCount: Int
        let avgSessionMinutes: Double
        let topExercises: [TopExercise]
        let newPRs: [NewPR]

        // `new_prs` -> `newPrs` under default snake-case decoding,
        // so we explicitly remap to `newPRs` for readable Swift naming.
        enum CodingKeys: String, CodingKey {
            case totalVolume
            case sessionCount
            case avgSessionMinutes
            case topExercises
            case newPRs = "newPrs"
        }
    }

    struct TopExercise: Codable, Hashable {
        let name: String
        let volume: Double
        let sets: Int
    }

    struct NewPR: Codable, Hashable {
        let exercise: String
        let weight: Double
        let reps: Int
    }

    // The backend names the stats field `stats_json`; with
    // `convertFromSnakeCase` that becomes `statsJson`, so map it
    // back to our `stats` property.
    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case periodStart
        case periodEnd
        case stats = "statsJson"
        case recommendationText
        case createdAt
        case readAt
        case feedbackRating
        case feedbackText
    }
}
