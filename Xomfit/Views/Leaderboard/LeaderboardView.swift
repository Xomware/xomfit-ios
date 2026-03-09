import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Controls
                VStack(spacing: 8) {
                    Picker("Scope", selection: $viewModel.selectedScope) {
                        ForEach(LeaderboardScope.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Picker("Metric", selection: $viewModel.selectedMetric) {
                            ForEach(LeaderboardMetric.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Time", selection: $viewModel.selectedTimeframe) {
                            ForEach(LeaderboardTimeframe.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .onChange(of: viewModel.selectedScope) { _ in viewModel.load() }
                .onChange(of: viewModel.selectedMetric) { _ in viewModel.load() }
                .onChange(of: viewModel.selectedTimeframe) { _ in viewModel.load() }
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        // Top 3 Podium
                        if viewModel.entries.count >= 3 {
                            PodiumView(entries: Array(viewModel.entries.prefix(3)))
                                .padding()
                        }
                        
                        // User rank highlight
                        if let rank = viewModel.userRank {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Your rank: #\(rank)")
                                    .bold()
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                        }
                        
                        // Full list
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.entries) { entry in
                                LeaderboardRowView(entry: entry)
                                Divider()
                            }
                        }
                        
                        // Trophy Case
                        if !viewModel.trophies.isEmpty {
                            TrophyCaseView(trophies: viewModel.trophies)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.load() }
        }
    }
}

// MARK: - Podium
struct PodiumView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count > 1 { podiumColumn(entries[1], height: 80) }
            if entries.count > 0 { podiumColumn(entries[0], height: 100) }
            if entries.count > 2 { podiumColumn(entries[2], height: 60) }
        }
    }
    
    func podiumColumn(_ entry: LeaderboardEntry, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(entry.badge ?? "")
                .font(.title)
            Text(entry.avatarInitials)
                .font(.caption)
                .bold()
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.2))
                .clipShape(Circle())
            Text(entry.displayName)
                .font(.caption2)
                .lineLimit(1)
            Text(entry.scoreFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: height)
                .cornerRadius(6)
            Text("#\(entry.rank)")
                .font(.caption)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var isCurrentUser: Bool { entry.userId == "current_user" }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text(entry.badge ?? "#\(entry.rank)")
                .font(.headline)
                .frame(width: 36)
            
            // Avatar
            Text(entry.avatarInitials)
                .font(.caption)
                .bold()
                .frame(width: 36, height: 36)
                .background(isCurrentUser ? Color.blue.opacity(0.2) : Color(.systemGray5))
                .clipShape(Circle())
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(isCurrentUser ? .blue : .primary)
                Text(entry.scoreFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Rank change
            Text(entry.rankChangeSymbol)
                .font(.caption)
                .foregroundColor(entry.rankChange > 0 ? .green : entry.rankChange < 0 ? .red : .gray)
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)
    }
}

// MARK: - Trophy Case
struct TrophyCaseView: View {
    let trophies: [Trophy]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trophy Case")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trophies) { trophy in
                        VStack(spacing: 6) {
                            Text(trophy.emoji)
                                .font(.system(size: 40))
                            Text(trophy.title)
                                .font(.caption)
                                .bold()
                                .multilineTextAlignment(.center)
                            Text(trophy.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(width: 120)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
