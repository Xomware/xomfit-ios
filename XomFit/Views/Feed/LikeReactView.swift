import SwiftUI

struct LikeReactView: View {
    let postId: String
    @State private var selectedReaction: ReactionType?
    @State private var showReactionPicker = false
    @State private var reactions: [ReactionType: Int] = [:]
    
    var body: some View {
        HStack(spacing: Theme.paddingSmall) {
            Menu {
                ForEach(ReactionType.allCases, id: \.self) { reaction in
                    Button(action: {
                        addReaction(reaction)
                    }) {
                        Label(reaction.emoji, systemImage: "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "smileyface")
                    Text("React")
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }
            
            // Display reactions
            HStack(spacing: 4) {
                ForEach(ReactionType.allCases, id: \.self) { reaction in
                    if let count = reactions[reaction], count > 0 {
                        Button(action: { toggleReaction(reaction) }) {
                            HStack(spacing: 2) {
                                Text(reaction.emoji)
                                Text("\(count)")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                selectedReaction == reaction
                                    ? Theme.accentColor.opacity(0.2)
                                    : Color.white.opacity(0.05)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load reactions from API in production
            reactions = [.like: 12, .fire: 3, .muscle: 7]
        }
    }
    
    private func addReaction(_ reaction: ReactionType) {
        reactions[reaction, default: 0] += 1
        selectedReaction = reaction
    }
    
    private func toggleReaction(_ reaction: ReactionType) {
        if selectedReaction == reaction {
            selectedReaction = nil
            reactions[reaction, default: 0] -= 1
        } else {
            selectedReaction = reaction
            reactions[reaction, default: 0] += 1
        }
    }
}

enum ReactionType: String, CaseIterable {
    case like = "👍"
    case fire = "🔥"
    case muscle = "💪"
    case clap = "👏"
    case star = "⭐"
    case crown = "👑"
    
    var emoji: String {
        self.rawValue
    }
}

// MARK: - Reaction Badge

struct ReactionBadge: View {
    let reaction: ReactionType
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(reaction.emoji)
                    .font(.system(size: 13))
                
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? Theme.accentColor.opacity(0.25)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    VStack(spacing: Theme.paddingMedium) {
        LikeReactView(postId: "test-post")
        
        HStack {
            ReactionBadge(reaction: .like, count: 12, isSelected: true) {}
            ReactionBadge(reaction: .fire, count: 5, isSelected: false) {}
            ReactionBadge(reaction: .muscle, count: 8, isSelected: false) {}
            Spacer()
        }
    }
    .padding()
    .background(Theme.background)
}
