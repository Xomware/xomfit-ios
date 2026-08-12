import SwiftUI

/// Collects the three attributes strength ranking needs: bodyweight, sex, and
/// age.
///
/// Ranking works without these — it falls back to midpoint standards and no age
/// allowance — but the result is noticeably off for anyone who is not an
/// average-aged male, which is why the rank card labels itself provisional
/// until this is filled in. Everything here stays on-device.
struct LifterDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var strength = StrengthLevelService.shared
    @State private var bodyweightText: String = ""
    @State private var sex: LifterSex = .unspecified
    @State private var birthYear: Int = 0

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// Oldest plausible lifter first is wrong for a picker people scroll — most
    /// users are closer to the recent end, so the range runs newest-first.
    private var yearRange: [Int] {
        Array((currentYear - 90)...(currentYear - 10)).reversed()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Bodyweight")
                        Spacer()
                        TextField("0", text: $bodyweightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("lb").foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text("Bodyweight")
                } footer: {
                    Text(strength.loggedBodyweight > 0
                         ? "Using your most recent logged weight. Logging a new measurement updates this automatically."
                         : "Strength ranks are relative to bodyweight, so this is the one value ranking cannot work without.")
                }

                Section {
                    Picker("Sex", selection: $sex) {
                        ForEach(LifterSex.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } footer: {
                    Text("Strength standards differ by sex. Leaving this unset uses a midpoint, which will misrank most lifters in one direction or the other.")
                }

                Section {
                    Picker("Birth year", selection: $birthYear) {
                        Text("Not set").tag(0)
                        ForEach(yearRange, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                } footer: {
                    Text("Standards are built around lifters in their physical prime. Setting this gives an age allowance so the top ranks stay reachable.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Your details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            sex = strength.sex
            birthYear = Calendar.current.component(.year, from: Date()) - (strength.age ?? 0)
            if strength.age == nil { birthYear = 0 }
            if strength.bodyweight > 0 {
                bodyweightText = strength.bodyweight.formattedWeight
            }
        }
    }

    private func save() {
        strength.sex = sex
        strength.setBirthYear(birthYear)
        // Only overwrite the manual value when the field holds something usable;
        // a logged measurement still takes precedence at read time.
        if let weight = Double(bodyweightText), weight > 0 {
            strength.setManualBodyweight(weight)
        }
        dismiss()
    }
}
