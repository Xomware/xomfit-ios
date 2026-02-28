import SwiftUI
import Charts
import PhotosUI

struct BodyCompositionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = BodyCompositionViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Loading...")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.paddingLarge) {
                            // Summary cards
                            summarySection
                            
                            // Metric selector + chart
                            chartSection
                            
                            // History log
                            historySection
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.bottom, Theme.paddingLarge)
                    }
                    .refreshable {
                        if let userId = authService.currentUser?.id {
                            await viewModel.load(userId: userId)
                        }
                    }
                }
            }
            .navigationTitle("Body Composition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddEntry) {
                AddBodyCompositionView(viewModel: viewModel)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            if let userId = authService.currentUser?.id {
                await viewModel.load(userId: userId)
            }
        }
    }
    
    // MARK: - Summary Section
    
    @ViewBuilder private var summarySection: some View {
        if let latest = viewModel.latestEntry {
            VStack(alignment: .leading, spacing: 12) {
                Text("Latest Check-in")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                
                Text(latest.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    if let weight = latest.weightLbs {
                        let (changeText, changeColor) = viewModel.formatChange(viewModel.weightChange30d, unit: " lbs", lowerIsBetter: false)
                        SummaryStatCard(
                            label: "Weight",
                            value: String(format: "%.1f", weight),
                            unit: "lbs",
                            change: changeText,
                            changeColor: changeColor,
                            icon: "scalemass.fill"
                        )
                    }
                    
                    if let waist = latest.waist {
                        let (changeText, changeColor) = viewModel.formatChange(viewModel.waistChange30d, unit: "\"", lowerIsBetter: true)
                        SummaryStatCard(
                            label: "Waist",
                            value: String(format: "%.1f", waist),
                            unit: "in",
                            change: changeText,
                            changeColor: changeColor,
                            icon: "figure.stand"
                        )
                    }
                    
                    if let bf = latest.bodyFatPercent {
                        let (changeText, changeColor) = viewModel.formatChange(viewModel.bodyFatChange30d, unit: "%", lowerIsBetter: true)
                        SummaryStatCard(
                            label: "Body Fat",
                            value: String(format: "%.1f", bf),
                            unit: "%",
                            change: changeText,
                            changeColor: changeColor,
                            icon: "percent"
                        )
                    }
                }
            }
            .cardStyle()
        }
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metric picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BodyMeasurement.allCases) { metric in
                        Button {
                            viewModel.selectedMetric = metric
                        } label: {
                            Text(metric.rawValue)
                                .font(Theme.fontCaption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedMetric == metric ? Theme.accent : Theme.cardBackground)
                                .foregroundStyle(viewModel.selectedMetric == metric ? .black : Theme.textSecondary)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Time range picker
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                ForEach(BodyCompositionViewModel.TimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            // Chart
            let data = viewModel.chartData
            if data.isEmpty {
                Text("No \(viewModel.selectedMetric.rawValue) data in this range")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            } else {
                Chart(data, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(viewModel.selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(viewModel.selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(viewModel.selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(40)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.textSecondary.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                            .font(.system(size: 11))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(Theme.textSecondary)
                            .font(.system(size: 11))
                    }
                }
                
                // Min/max/avg stats below chart
                if let min = data.map(\.value).min(),
                   let max = data.map(\.value).max() {
                    let avg = data.map(\.value).reduce(0, +) / Double(data.count)
                    HStack {
                        MiniStat(label: "Low", value: String(format: "%.1f", min), unit: viewModel.selectedMetric.unit)
                        Spacer()
                        MiniStat(label: "Avg", value: String(format: "%.1f", avg), unit: viewModel.selectedMetric.unit)
                        Spacer()
                        MiniStat(label: "High", value: String(format: "%.1f", max), unit: viewModel.selectedMetric.unit)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - History Section
    
    @ViewBuilder private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check-in History")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            
            if viewModel.entries.isEmpty {
                Text("No entries yet. Tap + to log your first check-in.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.paddingLarge)
            } else {
                ForEach(viewModel.entries) { entry in
                    BodyCompositionEntryRow(entry: entry) {
                        viewModel.entryToDelete = entry
                        viewModel.showingDeleteConfirm = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $viewModel.showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = viewModel.entryToDelete {
                    Task { await viewModel.deleteEntry(entry) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Supporting Views

private struct SummaryStatCard: View {
    let label: String
    let value: String
    let unit: String
    let change: String
    let changeColor: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Text(label)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text(change)
                .font(Theme.fontSmall)
                .foregroundStyle(changeColor)
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

private struct MiniStat: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct BodyCompositionEntryRow: View {
    let entry: BodyCompositionEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Date column
            VStack(alignment: .center, spacing: 2) {
                Text(entry.recordedAt.formatted(.dateTime.month(.abbreviated)))
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                Text(entry.recordedAt.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.recordedAt.formatted(.dateTime.year()))
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 44)
            
            // Measurements
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    if let w = entry.weightLbs {
                        MeasurementChip(label: "Weight", value: String(format: "%.1f lbs", w))
                    }
                    if let bf = entry.bodyFatPercent {
                        MeasurementChip(label: "Body Fat", value: String(format: "%.1f%%", bf))
                    }
                }
                
                HStack(spacing: 8) {
                    if let waist = entry.waist {
                        MeasurementChip(label: "Waist", value: String(format: "%.1f\"", waist))
                    }
                    if let chest = entry.chest {
                        MeasurementChip(label: "Chest", value: String(format: "%.1f\"", chest))
                    }
                    if let hips = entry.hips {
                        MeasurementChip(label: "Hips", value: String(format: "%.1f\"", hips))
                    }
                }
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                
                if entry.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

private struct MeasurementChip: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
