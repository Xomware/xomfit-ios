import Foundation

/// Workout -> CSV. Used by Settings "Export workouts" (#312).
///
/// Output columns: id, date, exercise, set, weight, reps.
/// `weight` is emitted in the user's chosen display unit; the column header
/// reflects the unit so the export is self-describing.
enum CSVExporter {

    /// One row per set across all workouts. Newest workouts first (caller's order is preserved).
    static func csv(for workouts: [Workout], unit: WeightUnit = .lbs) -> String {
        var lines: [String] = []
        lines.append("id,date,exercise,set,weight_\(unit.rawValue),reps")

        let isoFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        for workout in workouts {
            let dateString = isoFormatter.string(from: workout.startTime)
            for exercise in workout.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    let setNumber = index + 1
                    let weight = set.weight.formattedWeight(unit: unit)
                    let row = [
                        escape(workout.id),
                        escape(dateString),
                        escape(exercise.exercise.name),
                        "\(setNumber)",
                        weight,
                        "\(set.reps)"
                    ].joined(separator: ",")
                    lines.append(row)
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns the URL.
    /// Caller is responsible for handing the URL to a share sheet.
    static func writeToTempFile(csv: String, filename: String = "xomfit_workouts.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Private

    /// Escapes a CSV field per RFC 4180: wraps in quotes when it contains a
    /// comma, double-quote, or newline; doubles any embedded quotes.
    private static func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
