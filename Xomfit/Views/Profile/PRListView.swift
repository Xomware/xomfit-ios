import SwiftUI

struct PRListView: View {
    let userId: String

    @State private var prs: [PersonalRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                ProgressView()
                    .tint(Theme.accent)
            } else if prs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.0) { exerciseName, records in
                        Section {
                            ForEach(records) { pr in
                                PRRow(pr: pr)
                                    .listRowBackground(Theme.cardBackground)
                            }
                        } header: {
                            Text(exerciseName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.accent)
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
    }

    private var emptyState: some View {
        VStack(spacing: Theme.paddingMedium) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text("No PRs yet")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Complete sets during workouts to track your personal records")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingLarge)
        }
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
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: "trophy.fill")
                .foregroundColor(Theme.prGold)
                .font(.system(size: 20))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(pr.weight.formattedWeight) lbs × \(pr.reps) reps")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(dateString)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let pct = improvementPercent {
                    Text(pct)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                if let prev = pr.previousBest {
                    Text("Prev: \(prev.formattedWeight)")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
