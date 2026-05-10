import SwiftUI

/// Pure-Swift plate stack calculator. Given a target weight and bar weight,
/// greedily computes which plates to load on each side using the available
/// plate set. Stateless — no services, no persistence.
struct PlateCalculatorView: View {
    /// Optional pre-fill from the active set row's weight TextField.
    let initialTargetWeight: Double?

    init(initialTargetWeight: Double? = nil) {
        self.initialTargetWeight = initialTargetWeight
        _targetWeightText = State(initialValue: initialTargetWeight.map { $0.formattedWeight } ?? "")
    }

    @Environment(\.dismiss) private var dismiss

    // MARK: - Inputs

    @State private var targetWeightText: String
    @State private var barWeight: Double = 45
    /// Available plate set (lbs). Greedy descending order.
    @State private var availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    private static let standardBarWeights: [Double] = [45, 35, 25]
    @State private var customBarText: String = ""
    @State private var useCustomBar: Bool = false

    // MARK: - Derived

    private var targetWeight: Double {
        Double(targetWeightText) ?? 0
    }

    /// Per-side plate stack using a greedy algorithm. Returns plates heaviest
    /// first; `remainder` is what couldn't be loaded with the available set.
    private var stack: PlateStack {
        PlateCalculator.compute(
            target: targetWeight,
            bar: barWeight,
            plates: availablePlates
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        targetSection
                        barSection
                        platesSection
                        resultSection
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Sections

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Target Weight")
            HStack(spacing: Theme.Spacing.sm) {
                TextField("0", text: $targetWeightText)
                    .keyboardType(.decimalPad)
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.horizontal, Theme.Spacing.md)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .accessibilityLabel("Target weight in pounds")
                Text("lbs")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var barSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Bar Weight")
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Self.standardBarWeights, id: \.self) { w in
                    Button {
                        Haptics.selection()
                        useCustomBar = false
                        barWeight = w
                    } label: {
                        Text("\(w.formattedWeight)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(barWeight == w && !useCustomBar ? .black : Theme.textPrimary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(barWeight == w && !useCustomBar ? Theme.accent : Theme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(w.formattedWeight) pound bar")
                }
                Button {
                    Haptics.selection()
                    useCustomBar = true
                    if let v = Double(customBarText), v >= 0 { barWeight = v }
                } label: {
                    Text("Custom")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(useCustomBar ? .black : Theme.textPrimary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(useCustomBar ? Theme.accent : Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use custom bar weight")
            }

            if useCustomBar {
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("e.g. 15", text: $customBarText)
                        .keyboardType(.decimalPad)
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.vertical, Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.md)
                        .background(Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                        .onChange(of: customBarText) { _, newValue in
                            if let v = Double(newValue), v >= 0 { barWeight = v }
                        }
                        .accessibilityLabel("Custom bar weight in pounds")
                    Text("lbs")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var platesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Available Plates (lbs)")
            // Toggle chips for the standard plate set.
            FlowChipRow(items: Self.defaultPlates, selected: Set(availablePlates)) { plate in
                Haptics.selection()
                if availablePlates.contains(plate) {
                    availablePlates.removeAll { $0 == plate }
                } else {
                    availablePlates.append(plate)
                    availablePlates.sort(by: >)
                }
            }
            Text("Tap to toggle which plates you have on hand.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Per Side")
            if targetWeight <= 0 {
                Text("Enter a target weight to see the plate stack.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if targetWeight < barWeight {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.alert)
                    Text("Target is lighter than the bar (\(barWeight.formattedWeight) lbs).")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                plateStackVisualization
                summaryRow
                if stack.remainder > 0.0001 {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.alert)
                        Text("Couldn't load exactly. \(stack.remainder.formattedWeight) lbs short per side with selected plates.")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Plate visualization

    private var plateStackVisualization: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 4) {
                // Bar nub
                Rectangle()
                    .fill(Theme.textTertiary)
                    .frame(width: 18, height: 8)
                    .accessibilityHidden(true)

                ForEach(Array(stack.plates.enumerated()), id: \.offset) { _, plate in
                    plateView(weight: plate)
                }

                if stack.plates.isEmpty {
                    Text("Just the bar")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, Theme.Spacing.sm)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stack.accessibilityDescription)
    }

    private func plateView(weight: Double) -> some View {
        let height: CGFloat = plateHeight(for: weight)
        let width: CGFloat = plateWidth(for: weight)
        return RoundedRectangle(cornerRadius: 4)
            .fill(plateColor(for: weight))
            .frame(width: width, height: height)
            .overlay(
                Text(weight.formattedWeight)
                    .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-90))
            )
            .accessibilityHidden(true)
    }

    private func plateHeight(for weight: Double) -> CGFloat {
        switch weight {
        case 45...: return 90
        case 35..<45: return 78
        case 25..<35: return 66
        case 10..<25: return 54
        case 5..<10: return 42
        default: return 32
        }
    }

    private func plateWidth(for weight: Double) -> CGFloat {
        switch weight {
        case 45...: return 22
        case 25..<45: return 18
        case 10..<25: return 16
        default: return 12
        }
    }

    private func plateColor(for weight: Double) -> Color {
        switch weight {
        case 45...: return Color(hex: "1B4DCB") // blue 45
        case 35..<45: return Color(hex: "F5C84B") // gold 35
        case 25..<35: return Color(hex: "2E7D32") // green 25
        case 10..<25: return Color(hex: "B0B0B5") // chrome 10
        case 5..<10: return Color(hex: "1F1F26") // black 5
        default: return Color(hex: "8A6C2F") // bronze 2.5
        }
    }

    private var summaryRow: some View {
        HStack(spacing: Theme.Spacing.lg) {
            summaryStat(label: "Per Side", value: "\(stack.perSide.formattedWeight) lbs")
            summaryStat(label: "Bar", value: "\(barWeight.formattedWeight) lbs")
            summaryStat(label: "Total", value: "\(stack.total.formattedWeight) lbs")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(Theme.fontNumberMedium)
                .foregroundStyle(Theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Defaults

    static let defaultPlates: [Double] = [45, 35, 25, 10, 5, 2.5]
}

// MARK: - Plate Calculator engine

struct PlateStack: Equatable {
    /// Per-side plate sequence, heaviest first.
    var plates: [Double]
    /// Total per side (sum of `plates`).
    var perSide: Double
    /// Total loaded weight (bar + 2 × perSide).
    var total: Double
    /// Per-side weight that couldn't be matched with the available plate set.
    var remainder: Double

    var accessibilityDescription: String {
        if plates.isEmpty { return "Just the bar." }
        let counts = Dictionary(grouping: plates, by: { $0 })
            .map { (weight: $0.key, count: $0.value.count) }
            .sorted { $0.weight > $1.weight }
        let parts = counts.map { "\($0.count) at \($0.weight.formattedWeight)" }
        return "Per side: " + parts.joined(separator: ", ")
    }
}

enum PlateCalculator {
    /// Greedy plate calculator. Subtracts the heaviest plate that fits from the
    /// remaining per-side weight until either nothing fits or the target is
    /// satisfied. Plates may be reused (gym has many of each size).
    static func compute(target: Double, bar: Double, plates: [Double]) -> PlateStack {
        guard target > 0, bar >= 0 else {
            return PlateStack(plates: [], perSide: 0, total: bar, remainder: 0)
        }
        guard target >= bar else {
            return PlateStack(plates: [], perSide: 0, total: bar, remainder: 0)
        }
        var remaining = (target - bar) / 2.0
        // Tolerate floating-point noise (1g ≈ 0.0022 lbs).
        let epsilon = 0.001
        let sorted = plates.sorted(by: >)
        var picked: [Double] = []

        for plate in sorted {
            while remaining + epsilon >= plate {
                picked.append(plate)
                remaining -= plate
            }
        }

        let perSide = picked.reduce(0, +)
        let total = bar + perSide * 2
        let leftover = max(0, remaining)
        return PlateStack(
            plates: picked,
            perSide: perSide,
            total: total,
            remainder: leftover < epsilon ? 0 : leftover
        )
    }
}

// MARK: - Helper chip row

private struct FlowChipRow: View {
    let items: [Double]
    let selected: Set<Double>
    let onTap: (Double) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selected.contains(item)
                    Button {
                        onTap(item)
                    } label: {
                        Text(item.formattedWeight)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isSelected ? .black : Theme.textPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 8)
                            .background(isSelected ? Theme.accent : Theme.surfaceElevated)
                            .clipShape(.capsule)
                            .overlay(
                                Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.formattedWeight) pound plate")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}

#Preview {
    PlateCalculatorView(initialTargetWeight: 225)
        .preferredColorScheme(.dark)
}
