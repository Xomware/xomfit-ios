import Foundation

/// How a lifter sets up one machine. Free text because every brand labels its
/// adjustments differently — holes, letters, notches.
struct MachineSettings: Codable, Equatable {
    var seat = ""
    var pad = ""
    var handles = ""
    var notes = ""

    /// "Seat 4 · Handles neutral · feet high", or nil when nothing is set.
    var summary: String? {
        let parts = [("Seat", seat), ("Pad", pad), ("Handles", handles)]
            .filter { !$0.1.isEmpty }
            .map { "\($0.0) \($0.1)" } + (notes.isEmpty ? [] : [notes])
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
