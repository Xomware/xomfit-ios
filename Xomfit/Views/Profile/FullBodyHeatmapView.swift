import SwiftUI

/// Hevy-style full-body anatomy heatmap (#346).
///
/// Layout:
/// ┌────────────────────────────┐
/// │ Time range picker          │
/// │ Front / Back toggle        │
/// │   ┌──────────┐             │
/// │   │ silhouette│  ← tappable │
/// │   └──────────┘             │
/// │ Intensity legend           │
/// └────────────────────────────┘
///
/// Tap a muscle → presents `MuscleDetailSheet` with the exercises that hit it
/// in the selected range. The card lives on `ProfileStatsView` and replaces
/// the older grid-style `BodyHeatmapView`.
struct FullBodyHeatmapView: View {
    let workouts: [Workout]

    @State private var viewModel = BodyHeatmapViewModel()
    @State private var side: BodySide = .front
    @State private var selectedMuscle: MuscleGroup?

    init(workouts: [Workout]) {
        self.workouts = workouts
        // `_viewModel = State(initialValue: ...)` so the initial range/workouts are correct.
        _viewModel = State(initialValue: BodyHeatmapViewModel(workouts: workouts, range: .week))
    }

    /// Stable signature for `onChange` since `Workout` isn't `Equatable`. We
    /// use count + last-id which catches every real-world mutation (append,
    /// reload, swap) without forcing a full deep-equal walk.
    private var workoutsSignature: String {
        "\(workouts.count)-\(workouts.last?.id ?? "")"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            header
            rangePicker
            sideToggle
            silhouette
            legend
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
        )
        // `Workout` isn't Equatable, so compare a stable signature of the
        // workout list to know when to push fresh data into the view model.
        .onChange(of: workoutsSignature) { _, _ in
            viewModel.workouts = workouts
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailSheet(
                muscle: muscle,
                range: viewModel.range,
                totalVolume: viewModel.totalVolume(for: muscle),
                exercises: viewModel.exercises(for: muscle)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text("Muscle Heatmap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("Tap a muscle to see what hit it")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Time Range", selection: rangeBinding) {
            ForEach(HeatmapTimeRange.allCases) { r in
                Text(r.displayName).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range")
    }

    /// Binding wrapper so segmented picker writes flow into the view model.
    private var rangeBinding: Binding<HeatmapTimeRange> {
        Binding(
            get: { viewModel.range },
            set: { newValue in
                Haptics.selection()
                viewModel.range = newValue
            }
        )
    }

    // MARK: - Front / Back Toggle

    private var sideToggle: some View {
        HStack(spacing: 0) {
            ForEach(BodySide.allCases) { s in
                Button {
                    Haptics.selection()
                    withAnimation(.xomSnappy) { side = s }
                } label: {
                    Text(s.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(side == s ? Theme.background : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs + 2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                                .fill(side == s ? Theme.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("\(s.label) view")
                .accessibilityAddTraits(side == s ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(Theme.surfaceElevated)
        )
    }

    // MARK: - Silhouette

    private var silhouette: some View {
        BodySilhouetteView(
            side: side,
            fillByMuscle: viewModel.fillMap(),
            onMuscleTap: { muscle in
                selectedMuscle = muscle
            }
        )
        .frame(maxWidth: 280)
        .frame(height: 360)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: Theme.Spacing.sm) {
            legendItem(color: Theme.surface, label: "None")
            legendItem(color: Theme.accent.opacity(0.30), label: "Light")
            legendItem(color: Theme.accent.opacity(0.55), label: "Some")
            legendItem(color: Theme.accent.opacity(0.75), label: "Moderate")
            legendItem(color: Theme.accent.opacity(0.95), label: "Heavy")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Intensity legend: None, Light, Some, Moderate, Heavy")
    }

    private func legendItem(color: Color, label: String) -> some View {
        VStack(spacing: Theme.Spacing.tighter) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Theme.hairline, lineWidth: 0.5)
                )
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - MuscleGroup: Identifiable for sheet(item:)
// `MuscleGroup` already conforms to Identifiable via Models/Exercise.swift,
// so no extra conformance is needed here.

// MARK: - Preview

#Preview {
    ScrollView {
        FullBodyHeatmapView(workouts: [Workout.mock, Workout.mockFriendWorkout])
            .padding()
    }
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
