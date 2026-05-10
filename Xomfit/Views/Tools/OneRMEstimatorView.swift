import SwiftUI

/// Pure-Swift one-rep-max estimator. Takes a weight × reps lift and returns
/// estimates from three common formulas. Stateless — no services.
struct OneRMEstimatorView: View {
    /// Optional pre-fill from a PR row or set selection.
    let initialWeight: Double?
    let initialReps: Int?

    init(initialWeight: Double? = nil, initialReps: Int? = nil) {
        self.initialWeight = initialWeight
        self.initialReps = initialReps
        _weightText = State(initialValue: initialWeight.map { $0.formattedWeight } ?? "")
        _repsText   = State(initialValue: initialReps.map { "\($0)" } ?? "")
    }

    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String
    @State private var repsText: String

    private var weight: Double { Double(weightText) ?? 0 }
    private var reps: Int { Int(repsText) ?? 0 }

    /// 1RM is undefined for 0 reps, and 1-rep entries already are the 1RM.
    /// Brzycki blows up at 37 reps; we cap at 12 (where formulas stay sensible).
    private var validInput: Bool {
        weight > 0 && reps >= 1 && reps <= 12
    }

    private var estimates: OneRMEstimator.Result {
        OneRMEstimator.estimate(weight: weight, reps: reps)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        inputSection
                        if validInput {
                            recommendationSection
                            secondOpinionSection
                            disclaimer
                        } else {
                            placeholder
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle("1RM Estimator")
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

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Lift")
            HStack(spacing: Theme.Spacing.md) {
                inputField(label: "Weight (lbs)", text: $weightText, keyboard: .decimalPad)
                    .accessibilityLabel("Weight in pounds")
                inputField(label: "Reps", text: $repsText, keyboard: .numberPad)
                    .accessibilityLabel("Repetitions")
            }
            if reps > 12 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.alert)
                    Text("Estimates are unreliable above 12 reps. Use a heavier set.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.prGold)
                Text("Recommended (Epley)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.prGold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recommended estimate, Epley")
            .accessibilityAddTraits(.isHeader)

            Text("\(estimates.epley.formattedWeight) lbs")
                .font(Theme.fontDisplay)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("\(estimates.epley.formattedWeight) pounds")

            Text("Epley is the most common gym estimator. Treat it as a ceiling, not a guarantee.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.prGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var secondOpinionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Second Opinion")
            estimateRow(name: "Brzycki", value: estimates.brzycki, note: "Conservative, breaks down past ~10 reps")
            estimateRow(name: "Lombardi", value: estimates.lombardi, note: "Aggressive, useful for low-rep sets")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func estimateRow(name: String, value: Double, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(note)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("\(value.formattedWeight) lbs")
                .font(Theme.fontNumberMedium)
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) estimate: \(value.formattedWeight) pounds. \(note)")
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("Estimates extrapolate from your set. Always work up gradually with a spotter before testing a true 1RM.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.accentMuted)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Enter a weight and a rep count between 1 and 12 to see estimates.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Helpers

    private func inputField(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .font(Theme.fontNumberLarge)
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Estimator engine

enum OneRMEstimator {
    struct Result: Equatable {
        var epley: Double
        var brzycki: Double
        var lombardi: Double
    }

    /// Returns 1RM estimates from the three formulas. For reps == 1, all three
    /// degenerate to the input weight.
    static func estimate(weight: Double, reps: Int) -> Result {
        guard weight > 0, reps >= 1 else {
            return Result(epley: 0, brzycki: 0, lombardi: 0)
        }
        let r = Double(reps)
        let epley = weight * (1.0 + r / 30.0)
        let brzyckiDenom = 37.0 - r
        let brzycki = brzyckiDenom > 0 ? weight * 36.0 / brzyckiDenom : 0
        let lombardi = weight * pow(r, 0.10)
        return Result(epley: epley, brzycki: brzycki, lombardi: lombardi)
    }
}

#Preview {
    OneRMEstimatorView(initialWeight: 225, initialReps: 5)
        .preferredColorScheme(.dark)
}
