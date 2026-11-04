import Foundation

// MARK: - Weight Formatting

extension Double {
    /// Formats a weight value (stored internally in lbs) for display in the
    /// given unit. Values are converted display-only -- the underlying
    /// stored value is never mutated.
    ///
    /// - Parameters:
    ///   - unit: target display unit. Pass the user's `weightUnit` AppStorage value.
    ///   - includeUnit: when true, appends " lbs" or " kg" after the number.
    /// - Returns: a string like "135" / "61.2" / "135 lbs" / "61.2 kg".
    func formattedWeight(unit: WeightUnit, includeUnit: Bool = false) -> String {
        let converted = self * unit.multiplierFromLbs
        let body: String = converted.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", converted)
            : String(format: "%.1f", converted)
        return includeUnit ? "\(body) \(unit.displayName)" : body
    }
}

// MARK: - Weight / reps input parsing

/// Parses a weight typed in `unit` into stored lbs. Empty text is a cleared
/// field and parses to 0. Accepts a comma separator because `.decimalPad`
/// shows the locale's separator, and `Double("62,5")` is nil.
func parseWeightInput(_ text: String, unit: WeightUnit) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
          value.isFinite, value >= 0 else { return nil }
    return value / unit.multiplierFromLbs
}

/// Parses typed reps. Empty text is a cleared field and parses to 0.
func parseRepsInput(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    guard let value = Int(trimmed), value >= 0 else { return nil }
    return value
}

// MARK: - AppStorage helpers

/// Reads the user's saved weight unit from UserDefaults. Falls back to `.lbs`
/// when unset or invalid. Keep this in lockstep with `@AppStorage("weightUnit")`.
func currentWeightUnit() -> WeightUnit {
    let raw = UserDefaults.standard.string(forKey: "weightUnit") ?? WeightUnit.lbs.rawValue
    return WeightUnit(rawValue: raw) ?? .lbs
}
