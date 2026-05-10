import SwiftUI

// MARK: - ReportsListView
//
// Top-level Reports surface (#260). Lists weekly and monthly reports
// (newest first within each section) with an unread dot for any report
// where `readAt == nil`. Empty state covers the common "first week, no
// data yet" case.
//
// Deep-linked from `xomfit://report/<id>` via `XomfitApp.onOpenURL`,
// which programmatically pushes a `ReportDetailView` onto this screen's
// `NavigationStack`.

struct ReportsListView: View {
    @State private var viewModel = ReportsViewModel()

    /// Optional id captured from a `xomfit://report/<id>` deep-link.
    /// When the matching report shows up in `viewModel.reports`, we push
    /// the detail view automatically.
    var deepLinkReportId: String? = nil

    @State private var deepLinkedReport: UserReport? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.reports.isEmpty {
                loadingState
            } else if viewModel.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadAll()
            resolveDeepLinkIfPossible()
        }
        .refreshable {
            await viewModel.loadAll()
            resolveDeepLinkIfPossible()
        }
        // Programmatic push for deep-link arrivals. We use an
        // `item`-based navigation destination so dismissing the detail
        // view cleans up the binding for free.
        .navigationDestination(item: $deepLinkedReport) { report in
            ReportDetailView(report: report, viewModel: viewModel)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<3, id: \.self) { index in
                SkeletonCard(height: 92)
                    .staggeredAppear(index: index)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Empty

    private var emptyState: some View {
        // #311: longer empty-state copy that explains the cadence so users
        // don't read "no reports" as broken.
        XomEmptyState(
            icon: "doc.text.magnifyingglass",
            title: "No reports yet",
            subtitle: "Reports are auto-generated. Complete your first workout this week and we'll send your first weekly summary on Monday."
        )
    }

    // MARK: - List

    private var listContent: some View {
        List {
            if !viewModel.weeklyReports.isEmpty {
                Section {
                    ForEach(viewModel.weeklyReports) { report in
                        NavigationLink {
                            ReportDetailView(report: report, viewModel: viewModel)
                        } label: {
                            ReportRow(report: report)
                        }
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.hairline)
                    }
                } header: {
                    XomMetricLabel("Weekly")
                }
            }

            if !viewModel.monthlyReports.isEmpty {
                Section {
                    ForEach(viewModel.monthlyReports) { report in
                        NavigationLink {
                            ReportDetailView(report: report, viewModel: viewModel)
                        } label: {
                            ReportRow(report: report)
                        }
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.hairline)
                    }
                } header: {
                    XomMetricLabel("Monthly")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Deep Link Resolution

    private func resolveDeepLinkIfPossible() {
        guard let id = deepLinkReportId else { return }
        guard deepLinkedReport == nil else { return }
        if let match = viewModel.reports.first(where: { $0.id == id }) {
            deepLinkedReport = match
        }
        // If no match, fall back gracefully: the user lands on the list
        // and can pick a report manually. No alert / error toast — the
        // backend may simply not have ingested that id yet.
    }
}

// MARK: - ReportRow

private struct ReportRow: View {
    let report: UserReport

    private var isUnread: Bool { report.readAt == nil }

    private var iconName: String {
        switch report.kind {
        case .weekly:  "calendar.badge.clock"
        case .monthly: "calendar"
        }
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: report.periodStart)
        let end = formatter.string(from: report.periodEnd)
        return "\(start) – \(end)"
    }

    private var excerpt: String {
        // Trim newlines for compact list rendering.
        let single = report.recommendationText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return single.isEmpty
            ? "Tap to view your summary and recommendation."
            : single
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.accentMuted)
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(Theme.fontBodyEmphasized)
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(dateRangeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if isUnread {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                            .accessibilityLabel("Unread")
                    }
                }

                Text(excerpt)
                    .font(Theme.fontFootnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(report.kind.rawValue.capitalized) report, \(dateRangeText)\(isUnread ? ", unread" : "")"
        )
    }
}
