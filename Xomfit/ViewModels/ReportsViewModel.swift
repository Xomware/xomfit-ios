import Foundation

// MARK: - ReportsViewModel
//
// Drives `ReportsListView` + `ReportDetailView` for the Weekly Cron /
// Monthly Reports feature (#260). The service is intentionally
// fault-tolerant — when the backend hasn't shipped yet, `loadAll`
// returns no items and `errorMessage` stays nil so the empty state shows.

@MainActor
@Observable
final class ReportsViewModel {
    var reports: [UserReport] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    /// Reports grouped by kind for sectioned display, newest first.
    /// Weekly first, monthly second — matches the typical cadence.
    var weeklyReports: [UserReport] {
        reports
            .filter { $0.kind == .weekly }
            .sorted { $0.periodEnd > $1.periodEnd }
    }

    var monthlyReports: [UserReport] {
        reports
            .filter { $0.kind == .monthly }
            .sorted { $0.periodEnd > $1.periodEnd }
    }

    var isEmpty: Bool { reports.isEmpty && !isLoading }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            // Single fetch with no kind filter — backend returns both.
            let all = try await ReportsService.shared.fetchReports(kind: nil)
            // Defensive sort: newest period_end first.
            self.reports = all.sorted { $0.periodEnd > $1.periodEnd }
        } catch {
            // Service swallows most errors and returns []. Anything that
            // does propagate here is a hard failure worth surfacing.
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Mark Read

    /// Marks the given report as read. Optimistically updates local state
    /// regardless of backend status so the unread dot disappears
    /// immediately when the user taps in.
    func markRead(_ report: UserReport) async {
        guard report.readAt == nil else { return }

        // Optimistic local update.
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            let original = reports[index]
            reports[index] = UserReport(
                id: original.id,
                kind: original.kind,
                periodStart: original.periodStart,
                periodEnd: original.periodEnd,
                stats: original.stats,
                recommendationText: original.recommendationText,
                createdAt: original.createdAt,
                readAt: Date(),
                feedbackRating: original.feedbackRating,
                feedbackText: original.feedbackText
            )
        }

        do {
            try await ReportsService.shared.markRead(reportId: report.id)
        } catch {
            // Service already swallowed 404 / auth. Anything else is a
            // soft failure — keep the optimistic update; the next reload
            // from the backend will reconcile.
            print("[ReportsViewModel] markRead failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Submit Feedback

    func submitFeedback(report: UserReport, rating: Int, text: String?) async {
        // Trim text to nil so empty strings don't ship as feedback.
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = (trimmed?.isEmpty ?? true) ? nil : trimmed

        // Optimistic local update.
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            let original = reports[index]
            reports[index] = UserReport(
                id: original.id,
                kind: original.kind,
                periodStart: original.periodStart,
                periodEnd: original.periodEnd,
                stats: original.stats,
                recommendationText: original.recommendationText,
                createdAt: original.createdAt,
                readAt: original.readAt ?? Date(),
                feedbackRating: rating,
                feedbackText: normalizedText
            )
        }

        do {
            try await ReportsService.shared.submitFeedback(
                reportId: report.id,
                rating: rating,
                text: normalizedText
            )
        } catch {
            print("[ReportsViewModel] submitFeedback failed: \(error.localizedDescription)")
        }
    }
}
