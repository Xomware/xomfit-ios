import SwiftUI

struct PRListView: View {
    let userId: String

    @State private var prs: [PersonalRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// PR currently picked for the 1RM estimator sheet. nil = sheet hidden.
    @State private var oneRMSeed: PersonalRecord?

    // Group PRs by exercise name, each group sorted by date desc
    private var grouped: [(String, [PersonalRecord])] {
        let dict = Dictionary(grouping: prs, by: { $0.exerciseName })
        return dict
            .map { (key, values) in (key, values.sorted { $0.date > $1.date }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                XomFitLoaderPulse()
            } else if prs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.0) { exerciseName, records in
                        Section {
                            ForEach(Array(records.enumerated()), id: \.element.id) { index, pr in
                                PRRow(pr: pr, rank: index + 1)
                                    .listRowBackground(Theme.surface)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: Theme.Spacing.md))
                                    .contextMenu {
                                        Button {
                                            Haptics.selection()
                                            oneRMSeed = pr
                                        } label: {
                                            Label("1RM Estimate", systemImage: "function")
                                        }
                                    }
                            }
                        } header: {
                            Text(exerciseName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadPRs() }
        .refreshable { loadPRs() }
        .sheet(item: $oneRMSeed) { pr in
            OneRMEstimatorView(initialWeight: pr.weight, initialReps: pr.reps)
                .presentationDetents([.large])
        }
    }

    private var emptyState: some View {
        XomEmptyState(
            icon: "trophy",
            title: "No PRs yet",
            subtitle: "Complete sets during workouts to track your personal records"
        )
    }

    private func loadPRs() {
        Task {
            isLoading = true
            do {
                prs = try await PRService.shared.fetchPRs(userId: userId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - PR Row

private struct PRRow: View {
    let pr: PersonalRecord
    let rank: Int

    private var isTopThree: Bool { rank <= 3 }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: pr.date)
    }

    private var improvementPercent: String? {
        guard let prev = pr.previousBest, prev > 0 else { return nil }
        let pct = ((pr.weight - prev) / prev) * 100
        return String(format: "+%.1f%%", pct)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading gold stripe for top-3
            if isTopThree {
                Rectangle()
                    .fill(Theme.prGold)
                    .frame(width: 3)
            }

            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(isTopThree ? Theme.prGold : Theme.textTertiary)
                    .font(Theme.fontSubheadline)
                    .frame(width: Theme.Spacing.lg)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(pr.weight.formattedWeight) lbs \u{00D7} \(pr.reps) reps")
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(dateString)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if let pct = improvementPercent {
                        Text(pct)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    if let prev = pr.previousBest {
                        Text("Prev: \(prev.formattedWeight)")
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pr.weight.formattedWeight) lbs by \(pr.reps) reps on \(dateString)")
    }
}
