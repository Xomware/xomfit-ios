import SwiftUI

struct ChallengeView: View {
    @StateObject private var viewModel = ChallengeViewModel()
    @State private var selectedTab = 0
    @State private var showCreateChallenge = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Challenges")
                                .font(.system(size: 32, weight: .bold))
                            Text("Compete with friends")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { showCreateChallenge = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Tab selector
                    Picker("", selection: $selectedTab) {
                        Text("Active").tag(0)
                        Text("My Challenges").tag(1)
                        Text("All").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
                
                // Content
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    TabView(selection: $selectedTab) {
                        // Active Challenges
                        activeChallengesView
                            .tag(0)
                        
                        // My Challenges
                        myChallengesView
                            .tag(1)
                        
                        // All Challenges
                        allChallengesView
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                        Spacer()
                        Button(action: { viewModel.errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView(isPresented: $showCreateChallenge, viewModel: viewModel) { challenge in
                viewModel.challenges.append(challenge)
            }
        }
        .task {
            await viewModel.fetchChallenges()
        }
    }
    
    @ViewBuilder
    private var activeChallengesView: some View {
        if viewModel.activeChallenges.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "flame.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text("No Active Challenges")
                    .font(.headline)
                Text("Create one to get started!")
                    .font(.caption)
                    .foregroundColor(.gray)
                Button(action: { showCreateChallenge = true }) {
                    Text("Create Challenge")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeChallenges) { challenge in
                        ChallengeCardView(challenge: challenge)
                            .onTapGesture {
                                Task {
                                    await viewModel.fetchChallengeDetail(challengeId: challenge.id)
                                }
                            }
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var myChallengesView: some View {
        if viewModel.userChallenges.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("No Challenges Yet")
                    .font(.headline)
                Text("You'll see challenges you've joined here")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.userChallenges) { challenge in
                        ChallengeCardView(challenge: challenge)
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var allChallengesView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.challenges) { challenge in
                    ChallengeCardView(challenge: challenge)
                }
            }
            .padding()
        }
    }
}

// MARK: - Challenge Card View
struct ChallengeCardView: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.type.displayName)
                        .font(.headline)
                    Text(challenge.type.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusBadge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(6)
                    Text("\(challenge.daysRemaining)d left")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Progress bar
            ProgressView(value: challenge.progressPercentage)
                .tint(.blue)
            
            // Participants
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.gray)
                Text("\(challenge.participants.count) participants")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 2) {
                    Text("Ends:")
                        .font(.caption2)
                    Text(challenge.endDate, style: .date)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusBadge: String {
        switch challenge.status {
        case .upcoming: return "Upcoming"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private var statusColor: Color {
        switch challenge.status {
        case .upcoming: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

// MARK: - Create Challenge View
struct CreateChallengeView: View {
    @Binding var isPresented: Bool
    @State private var selectedType: ChallengeType = .mostVolume
    @State private var selectedFriends: Set<String> = []
    @State private var friends: [FriendForChallenge] = []
    @State private var isLoadingFriends = true
    @ObservedObject var viewModel: ChallengeViewModel
    var onCreated: (Challenge) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Challenge Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ChallengeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedType.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Duration: \(selectedType.durationDays) days")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
                
                Section("Invite Friends") {
                    if isLoadingFriends {
                        ProgressView()
                    } else if friends.isEmpty {
                        Text("No friends found. Add friends to create a challenge!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(friends) { friend in
                                HStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.5))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(friend.initials)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(friend.displayName)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { selectedFriends.contains(friend.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedFriends.insert(friend.id)
                                            } else {
                                                selectedFriends.remove(friend.id)
                                            }
                                        }
                                    ))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(selectedFriends.isEmpty)
                }
            }
            .task {
                friends = await viewModel.fetchFriendsForChallenge()
                isLoadingFriends = false
            }
        }
    }
    
    private func createChallenge() {
        let challenge = Challenge(
            id: UUID().uuidString,
            type: selectedType,
            status: .upcoming,
            createdBy: "current_user",
            participants: Array(selectedFriends),
            startDate: Date().addingTimeInterval(86400), // Tomorrow
            endDate: Date().addingTimeInterval(86400 * Double(selectedType.durationDays)),
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        onCreated(challenge)
        isPresented = false
    }
}

#Preview {
    ChallengeView()
}
