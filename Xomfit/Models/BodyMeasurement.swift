import Foundation
import SwiftUI

// MARK: - BodyMeasurement (#317)
//
// Single-metric measurement entry. One row per (kind, recordedAt) so the
// time series for any kind can be plotted independently. Photos are intentionally
// out of scope here — they ship in a follow-up PR.
//
// Storage assumption: weights in lbs, lengths in inches, body-fat in %.
// Conversion to metric is a display-time concern.
//
struct BodyMeasurement: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let kind: MeasurementKind
    let value: Double
    let recordedAt: Date
    let notes: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        kind: MeasurementKind,
        value: Double,
        recordedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.value = value
        self.recordedAt = recordedAt
        self.notes = notes
    }
}

// MARK: - MeasurementKind

enum MeasurementKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case weight
    case bodyFatPercent = "body_fat_percent"
    case chest
    case waist
    case arm
    case thigh
    case calf
    case neck
    case shoulders
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight:          return "Weight"
        case .bodyFatPercent:  return "Body Fat"
        case .chest:           return "Chest"
        case .waist:           return "Waist"
        case .arm:             return "Arm"
        case .thigh:           return "Thigh"
        case .calf:            return "Calf"
        case .neck:            return "Neck"
        case .shoulders:       return "Shoulders"
        case .custom:          return "Custom"
        }
    }

    /// Display unit. Lengths use inches; weight uses lbs; body fat uses percent.
    var unit: String {
        switch self {
        case .weight:         return "lbs"
        case .bodyFatPercent: return "%"
        default:              return "in"
        }
    }

    /// SF Symbol used on the measurements list / detail header.
    var systemImage: String {
        switch self {
        case .weight:          return "scalemass.fill"
        case .bodyFatPercent:  return "percent"
        case .chest:           return "figure.arms.open"
        case .waist:           return "figure.stand"
        case .arm:             return "figure.strengthtraining.traditional"
        case .thigh:           return "figure.walk"
        case .calf:            return "figure.walk"
        case .neck:            return "figure.stand"
        case .shoulders:       return "figure.arms.open"
        case .custom:          return "ruler"
        }
    }

    /// Sensible numeric step for the log-entry stepper / number pad.
    var step: Double {
        switch self {
        case .weight:         return 0.5
        case .bodyFatPercent: return 0.1
        default:              return 0.25
        }
    }

    /// Reasonable input bounds (used to gate validation, not as a hard cap on history).
    var inputRange: ClosedRange<Double> {
        switch self {
        case .weight:         return 30...700
        case .bodyFatPercent: return 1...75
        default:              return 1...100
        }
    }

    /// Format a stored value for display (no unit suffix). Two-decimal max, trims trailing zeros.
    func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
