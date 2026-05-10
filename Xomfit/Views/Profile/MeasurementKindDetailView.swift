import Charts
import SwiftUI

// MARK: - MeasurementKindDetailView (#317)
//
// Time-series chart for one `MeasurementKind` plus an inline form to log a new
// entry. The view binds to the parent `MeasurementsViewModel` so writes update
// every kind's series consistently.
//
struct MeasurementKindDetailView: View {
    let kind: MeasurementKind

    @Bindable var viewModel: MeasurementsViewModel

    @State private var range: TimeRange = .threeMonths
    @State private var valueText: String = ""
    @State private var notesText: String = ""
    @State private var entryDate: Date = Date()
    @State private var isSaving: Bool = false
    @State private var pendingDelete: BodyMeasurement?
    @State private var isDeleteAlertPresented: Bool = false

    @FocusState private var valueFocused: Bool

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .oneMonth:    return 30
            case .threeMonths: return 90
            case .sixMonths:   return 180
            case .year:        return 365
            case .all:         return nil
            }
        }
    }

    private var allEntries: [BodyMeasurement] {
        viewModel.byKind[kind] ?? []
    }

    private var rangedEntries: [BodyMeasurement] {
        guard let days = range.days else { return allEntries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return allEntries.filter { $0.recordedAt >= cutoff }
    }

    /// Chart data is oldest-first so the line reads left to right.
    private var chartPoints: [BodyMeasurement] {
        rangedEntries.sorted { $0.recordedAt < $1.recordedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                summaryCard
                rangePicker
                chartCard
                logEntryCard
                historySection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, 100)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .alert(
            "Delete measurement?",
            isPresented: $isDeleteAlertPresented,
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                Task { await viewModel.remove(entry) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { entry in
            Text("This will remove the \(kind.format(entry.value)) \(kind.unit) entry from \(entry.recordedAt.formatted(date: .abbreviated, time: .omitted)).")
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        XomCard(variant: .elevated) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: kind.systemImage)
                    .font(Theme.fontTitle2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accentMuted)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    if let latest = viewModel.latest(of: kind) {
                        Text("\(kind.format(latest.value)) \(kind.unit)")
                            .font(Theme.fontNumberLarge)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Last logged \(latest.recordedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Not logged yet")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Add your first entry below")
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                deltaPill
            }
        }
    }

    @ViewBuilder
    private var deltaPill: some View {
        if let delta = viewModel.delta(for: kind, days: 30) {
            let lowerIsBetter = (kind == .waist || kind == .bodyFatPercent)
            let isPositive = lowerIsBetter ? delta < 0 : delta > 0
            let bg: Color = abs(delta) < 0.05
                ? Theme.surface
                : (isPositive ? Theme.accentMuted : Theme.destructive.opacity(0.15))
            let fg: Color = abs(delta) < 0.05
                ? Theme.textSecondary
                : (isPositive ? Theme.accent : Theme.destructive)
            let prefix = delta > 0 ? "+" : ""
            VStack(alignment: .trailing, spacing: Theme.Spacing.tighter) {
                Text("\(prefix)\(kind.format(delta))")
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(fg)
                Text("30d")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartCard: some View {
        XomCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Trend")
                    .font(Theme.fontSubheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                if chartPoints.count >= 2 {
                    chart
                        .frame(height: 180)
                } else if chartPoints.count == 1 {
                    Text("Add another entry to see a trend")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                } else {
                    Text("No data in this range")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }
            }
        }
    }

    private var chart: some View {
        Chart(chartPoints) { point in
            LineMark(
                x: .value("Date", point.recordedAt),
                y: .value(kind.displayName, point.value)
            )
            .foregroundStyle(Theme.accent)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", point.recordedAt),
                y: .value(kind.displayName, point.value)
            )
            .foregroundStyle(Theme.accent)
            .symbolSize(40)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(kind.format(v))
                            .font(Theme.fontCaption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel()
                    .font(Theme.fontCaption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - Log entry form

    private var logEntryCard: some View {
        XomCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Log new entry")
                    .font(Theme.fontSubheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Value", text: $valueText)
                        .keyboardType(.decimalPad)
                        .focused($valueFocused)
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .accessibilityLabel("Measurement value in \(kind.unit)")

                    Text(kind.unit)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 36, alignment: .leading)
                }

                DatePicker(
                    "Date",
                    selection: $entryDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)

                TextField("Notes (optional)", text: $notesText, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .accessibilityLabel("Notes")

                XomButton(
                    "Save Entry",
                    icon: "checkmark.circle.fill",
                    isLoading: isSaving,
                    action: saveEntry
                )
                .disabled(!isValueValid || isSaving)
                .opacity(isValueValid ? 1 : 0.5)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.destructive)
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if !allEntries.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("History")
                    .font(Theme.fontSubheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xs)

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(allEntries) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    private func historyRow(_ entry: BodyMeasurement) -> some View {
        XomCard(padding: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                    Text("\(kind.format(entry.value)) \(kind.unit)")
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(entry.recordedAt, style: .date)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    Haptics.light()
                    pendingDelete = entry
                    isDeleteAlertPresented = true
                } label: {
                    Image(systemName: "trash")
                        .font(Theme.fontSubheadline)
                        .foregroundStyle(Theme.destructive)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Delete entry")
            }
        }
    }

    // MARK: - Actions

    private var parsedValue: Double? {
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var isValueValid: Bool {
        guard let value = parsedValue else { return false }
        return kind.inputRange.contains(value)
    }

    private func saveEntry() {
        guard let value = parsedValue, !isSaving else { return }
        isSaving = true
        valueFocused = false
        Haptics.light()

        Task {
            await viewModel.add(
                kind: kind,
                value: value,
                recordedAt: entryDate,
                notes: notesText
            )
            isSaving = false
            if viewModel.errorMessage == nil {
                Haptics.success()
                resetForm()
            }
        }
    }

    private func resetForm() {
        valueText = ""
        notesText = ""
        entryDate = Date()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeasurementKindDetailView(
            kind: .weight,
            viewModel: MeasurementsViewModel()
        )
    }
    .background(Theme.background)
}
