import SwiftUI

/// View for accepting or declining a challenge invitation
struct JoinChallengeView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isJoining = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Challenge Info
                VStack(spacing: 16) {
                    Image(systemName: challenge.type.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text(challenge.type.displayName)
                        .font(.title2.weight(.bold))

                    Text(challenge.type.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Details Card
                VStack(spacing: 12) {
                    DetailRow(label: "Duration", value: "\(challenge.type.durationDays) days")
                    DetailRow(label: "Participants", value: "\(challenge.participants.count)")
                    DetailRow(label: "Starts", value: challenge.startDate.formatted(date: .abbreviated, time: .omitted))
                    DetailRow(label: "Ends", value: challenge.endDate.formatted(date: .abbreviated, time: .omitted))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isJoining = true
                        Task {
                            let success = await viewModel.joinChallenge(challengeId: challenge.id)
                            isJoining = false
                            if success {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Join Challenge")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isJoining)

                    Button(action: {
                        Task {
                            await viewModel.declineChallenge(challengeId: challenge.id)
                            dismiss()
                        }
                    }) {
                        Text("Decline")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Challenge Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    let mockChallenge = Challenge(
        id: "ch1",
        type: .longestStreak,
        status: .upcoming,
        createdBy: "user1",
        participants: ["user1", "user2"],
        startDate: Date(),
        endDate: Date().addingTimeInterval(86_400 * 30),
        results: [],
        createdAt: Date(),
        updatedAt: Date()
    )
    return JoinChallengeView(
        challenge: mockChallenge,
        viewModel: ChallengeViewModel()
    )
}
