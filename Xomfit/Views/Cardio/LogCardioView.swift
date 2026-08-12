import SwiftUI

/// Hand-logs a cardio session.
///
/// Cardio arriving from Apple Health covers anything recorded on a watch, but
/// plenty of cardio happens on a gym machine with no wearable involved — the
/// stair master reading you copy off the console, the treadmill you ran without
/// your watch. Without this, that work is simply unloggable.
///
/// The form adapts to the modality: distance and elevation only appear where
/// they mean something, so an elliptical session never asks for a distance it
/// cannot meaningfully report.
struct LogCardioView: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    /// Called after a successful save so the caller can refresh its list.
    var onSaved: (() -> Void)?

    @State private var modality: CardioModality = .outdoorRun
    @State private var date: Date = Date()
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0
    @State private var distanceText: String = ""
    @State private var caloriesText: String = ""
    @State private var avgHeartRateText: String = ""
    @State private var elevationText: String = ""
    @State private var notes: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var durationSeconds: Double {
        Double(hours * 3600 + minutes * 60 + seconds)
    }

    private var canSave: Bool {
        durationSeconds > 0 && !isSaving
    }

    /// Live pace preview, so the lifter can sanity-check what they typed before
    /// saving rather than discovering a fat-fingered distance in their history.
    private var pacePreview: String? {
        guard durationSeconds > 0,
              let distance = Double(distanceText), distance > 0 else { return nil }
        let preview = CardioSession(
            id: "preview", userId: userId, modality: modality,
            startTime: date, endTime: date.addingTimeInterval(durationSeconds),
            durationSeconds: durationSeconds, distanceMiles: distance
        )
        return preview.paceDisplay
    }

    var body: some View {
        NavigationStack {
            Form {
                modalitySection
                durationSection
                metricsSection

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.alert)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Log Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Sections

    private var modalitySection: some View {
        Section {
            Picker("Type", selection: $modality) {
                ForEach(CardioModality.allCases) { option in
                    Label(option.displayName, systemImage: option.icon).tag(option)
                }
            }
            DatePicker("When", selection: $date, in: ...Date())
        }
    }

    private var durationSection: some View {
        Section {
            HStack(spacing: 0) {
                durationWheel("hr", value: $hours, range: 0...23)
                durationWheel("min", value: $minutes, range: 0...59)
                durationWheel("sec", value: $seconds, range: 0...59)
            }
            .frame(height: 120)
        } header: {
            Text("Duration")
        } footer: {
            if durationSeconds == 0 {
                Text("A session needs a duration — everything else is optional.")
            }
        }
    }

    private func durationWheel(
        _ label: String, value: Binding<Int>, range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 2) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            Text(label)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value.wrappedValue)")
    }

    @ViewBuilder
    private var metricsSection: some View {
        Section {
            // Only shown where the modality actually reports it — asking for a
            // distance on an elliptical just invites junk data.
            if modality.tracksDistance {
                metricField("Distance", text: $distanceText, unit: "mi")
            }
            metricField("Calories", text: $caloriesText, unit: "kcal")
            metricField("Avg heart rate", text: $avgHeartRateText, unit: "bpm")
            if modality.tracksElevation {
                metricField("Elevation gain", text: $elevationText, unit: "ft")
            }
        } header: {
            Text("Metrics")
        } footer: {
            if let pacePreview {
                Text(modality.prefersPaceOverSpeed ? "Pace: \(pacePreview)" : "Speed: \(pacePreview)")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func metricField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 36, alignment: .leading)
        }
    }

    // MARK: - Save

    private func save() async {
        guard durationSeconds > 0 else { return }
        isSaving = true
        errorMessage = nil

        let session = CardioSession(
            id: UUID().uuidString,
            userId: userId,
            modality: modality,
            startTime: date,
            endTime: date.addingTimeInterval(durationSeconds),
            durationSeconds: durationSeconds,
            // Distance is dropped rather than stored when the modality does not
            // track it, so a value typed before switching type cannot linger.
            distanceMiles: modality.tracksDistance ? Double(distanceText) : nil,
            activeCalories: Double(caloriesText),
            averageHeartRate: Double(avgHeartRateText),
            maxHeartRate: nil,
            elevationGainFeet: modality.tracksElevation ? Double(elevationText) : nil,
            notes: notes.isEmpty ? nil : notes
        )

        let saved = await CardioService.shared.save(session)
        isSaving = false

        if saved {
            Haptics.success()
            onSaved?()
            dismiss()
        } else {
            errorMessage = CardioService.shared.lastError
                ?? "Couldn't save that session. Check your connection and try again."
        }
    }
}
