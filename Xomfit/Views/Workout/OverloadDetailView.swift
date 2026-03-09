import SwiftUI

/// Full detail sheet showing exercise history and the current overload suggestion.
struct OverloadDetailView: View {
    let suggestion: OverloadSuggestion
    let sessions: [ExerciseSession]
    @Environment(\.dismiss) private var dismiss
    
    private let cyanAccent = Color(hex: "#00b4d8")
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingMedium) {
                        // Current Suggestion Card
                        suggestionCard
                        
                        // History Table
                        if !sessions.isEmpty {
                            historySection
                        }
                    }
                    .padding(Theme.paddingMedium)
                }
            }
            .navigationTitle(suggestion.exercise)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(cyanAccent)
                }
            }
        }
    }
    
    // MARK: - Suggestion Card
    
    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(cyanAccent)
                Text("Suggestion")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text(suggestion.explanation)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Suggestion type badge
            HStack {
                Text(suggestionBadgeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(suggestionBadgeColor)
                    .cornerRadius(6)
                Spacer()
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var suggestionBadgeText: String {
        switch suggestion.type {
        case .increaseWeight(let by, _): return "+\(by.formattedWeight) lbs"
        case .increaseReps(let by): return "+\(by) rep"
        case .deload: return "DELOAD"
        case .maintain: return "MAINTAIN"
        case .volumeStagnant: return "STAGNANT"
        }
    }
    
    private var suggestionBadgeColor: Color {
        switch suggestion.type {
        case .increaseWeight: return cyanAccent
        case .increaseReps: return .green
        case .deload: return .orange
        case .maintain: return .gray
        case .volumeStagnant: return .yellow
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            // Header
            HStack(spacing: 0) {
                Text("DATE").frame(maxWidth: .infinity, alignment: .leading)
                Text("WEIGHT").frame(width: 60, alignment: .trailing)
                Text("REPS").frame(width: 45, alignment: .trailing)
                Text("RPE").frame(width: 40, alignment: .trailing)
                Text("VOL").frame(width: 60, alignment: .trailing)
                Text("").frame(width: 20, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Theme.textSecondary)
            
            let sorted = sessions.sorted { $0.date > $1.date }
            ForEach(Array(sorted.enumerated()), id: \.offset) { index, session in
                HStack(spacing: 0) {
                    Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(session.maxWeight.formattedWeight)")
                        .frame(width: 60, alignment: .trailing)
                    Text("\(session.maxReps)")
                        .frame(width: 45, alignment: .trailing)
                    Text(String(format: "%.0f", session.avgRPE))
                        .frame(width: 40, alignment: .trailing)
                    Text("\(Int(session.totalVolume))")
                        .frame(width: 60, alignment: .trailing)
                    // Trend indicator
                    Text(trendIndicator(index: index, sessions: sorted))
                        .frame(width: 20, alignment: .trailing)
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .padding(.vertical, 6)
                
                if index < sorted.count - 1 {
                    Divider().background(Theme.textSecondary.opacity(0.3))
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    /// Compare volume to next-older session for trend indicator.
    private func trendIndicator(index: Int, sessions: [ExerciseSession]) -> String {
        guard index < sessions.count - 1 else { return "—" }
        let current = sessions[index].totalVolume
        let previous = sessions[index + 1].totalVolume
        if current > previous { return "↑" }
        if current < previous { return "↓" }
        return "→"
    }
}
