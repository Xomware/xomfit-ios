import Foundation

/// How a lifter sets up one machine. Free text because every brand labels its
/// adjustments differently — holes, letters, notches.
struct MachineSettings: Codable, Equatable {
    var seat = ""
    var pad = ""
    var handles = ""
    var notes = ""

    /// "Seat 4 · Pad 2 · Handles neutral", or nil when nothing is set.
    var summary: String? {
        let parts = [("Seat", seat), ("Pad", pad), ("Handles", handles)]
            .filter { !$0.1.isEmpty }
            .map { "\($0.0) \($0.1)" }
        let line = parts.isEmpty ? notes : parts.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }
}
