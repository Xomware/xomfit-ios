import SwiftUI

// MARK: - MeasurementsView (#317)
//
// One row per `MeasurementKind`, showing the latest value and 30-day delta.
// Tapping a row drills into `MeasurementKindDetailView` for the chart + log form.
//
// TODO(#317-photos): Progress photos ship in a follow-up PR. When they land,
// surface a thumbnail strip / "Photos" entry above the kinds list.
//
struct MeasurementsView: View {
    let userId: String

    @State private var viewModel = MeasurementsViewModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.measurements.isEmpty {
                loadingState
            } else if viewModel.measurements.isEmpty {
                emptyState
            } else {
                measurementsList
            }
        }
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadAll(userId: userId)
        }
        .refreshable {
            await viewModel.loadAll(userId: userId)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonCard(height: 64)
                    .staggeredAppear(index: index)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                XomEmptyState(
                    icon: "ruler",
                    title: "No measurements yet",
                    subtitle: "Track your weight, body fat, and circumference measurements over time.",
                    floatingLoop: true
                )

                quickStartGrid
                    .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.xl)
        }
    }

    /// Grid of all kinds even when empty — invites the user to start logging.
    private var quickStartGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(MeasurementKind.allCases) { kind in
                NavigationLink {
                    MeasurementKindDetailView(kind: kind, viewModel: viewModel)
                        .hideTabBar()
                } label: {
                    quickStartCard(for: kind)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Log \(kind.displayName)")
            }
        }
    }

    private func quickStartCard(for kind: MeasurementKind) -> some View {
        XomCard(padding: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(height: 24)

                Text(kind.displayName)
                    .font(Theme.fontSubheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Tap to log")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    // MARK: - Populated list

    private var measurementsList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(MeasurementKind.allCases) { kind in
                    NavigationLink {
                        MeasurementKindDetailView(kind: kind, viewModel: viewModel)
                            .hideTabBar()
                    } label: {
                        MeasurementKindRow(
                            kind: kind,
                            latest: viewModel.latest(of: kind),
                            delta: viewModel.delta(for: kind, days: 30)
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityHint("Opens chart and log entry form")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Row

private struct MeasurementKindRow: View {
    let kind: MeasurementKind
    let latest: BodyMeasurement?
    let delta: Double?

    var body: some View {
        XomCard {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.displayName)
                        .font(Theme.fontSubheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    deltaCaption
                }

                Spacer()

                latestValue
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var latestValue: some View {
        if let latest {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(kind.format(latest.value)) \(kind.unit)")
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.textPrimary)
                Text(latest.recordedAt, style: .date)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
        } else {
            Text("Tap to log")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var deltaCaption: some View {
        if let delta {
            let lowerIsBetter = (kind == .waist || kind == .bodyFatPercent)
            let isPositiveChange = lowerIsBetter ? delta < 0 : delta > 0
            let color: Color = abs(delta) < 0.05
                ? Theme.textSecondary
                : (isPositiveChange ? Theme.accent : Theme.destructive)
            let prefix = delta > 0 ? "+" : ""
            Text("\(prefix)\(kind.format(delta)) \(kind.unit) · 30d")
                .font(Theme.fontSmall)
                .foregroundStyle(color)
        } else {
            Text("No trend yet")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = [kind.displayName]
        if let latest {
            parts.append("\(kind.format(latest.value)) \(kind.unit)")
        }
        if let delta {
            let direction = delta > 0 ? "up" : "down"
            parts.append("\(direction) \(kind.format(abs(delta))) \(kind.unit) over 30 days")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeasurementsView(userId: "preview-user")
    }
    .background(Theme.background)
}
