import Foundation

/// User-selectable weight unit. Persisted via `@AppStorage("weightUnit")`.
/// Storage is always lbs internally; this enum drives display-only conversion.
/// Conversion uses 1 lb = 0.4536 kg (display only -- never round-trip stored data).
enum WeightUnit: String, CaseIterable, Identifiable {
    case lbs
    case kg

    var id: String { rawValue }

    /// User-facing label (e.g. "lbs", "kg").
    var displayName: String {
        switch self {
        case .lbs: return "lbs"
        case .kg:  return "kg"
        }
    }

    /// Long form for accessibility / VoiceOver.
    var accessibilityName: String {
        switch self {
        case .lbs: return "pounds"
        case .kg:  return "kilograms"
        }
    }

    /// Multiplier from internally-stored lbs to this display unit.
    var multiplierFromLbs: Double {
        switch self {
        case .lbs: return 1.0
        case .kg:  return 0.4536
        }
    }
}
