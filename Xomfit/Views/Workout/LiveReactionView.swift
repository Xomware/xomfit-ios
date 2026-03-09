import SwiftUI

/// View for displaying reactions/cheers during live workout
struct LiveReactionView: View {
    @State private var animatingReactions: [AnimatingReaction] = []
    @State private var nextID: UUID = UUID()
    
    let reactions: [LiveReaction]
    let onReactionTapped: (String) -> Void
    
    private let allowedEmojis = ["💪", "🔥", "👏", "🎯", "😤", "🙌", "⚡", "💯"]
    
    var body: some View {
        ZStack(alignment: .top) {
            // Animated reactions falling
            ForEach(animatingReactions, id: \.id) { animReaction in
                FloatingEmojiView(emoji: animReaction.emoji, id: animReaction.id)
            }
            
            // Quick reaction buttons at bottom
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    ForEach(allowedEmojis, id: \.self) { emoji in
                        Button(action: {
                            handleReactionTapped(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func handleReactionTapped(_ emoji: String) {
        onReactionTapped(emoji)
        
        // Create animating reaction
        let animating = AnimatingReaction(id: nextID, emoji: emoji)
        nextID = UUID()
        animatingReactions.append(animating)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            animatingReactions.removeAll { $0.id == animating.id }
        }
    }
}

/// Individual floating emoji that animates upward
struct FloatingEmojiView: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    
    let emoji: String
    let id: UUID
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 32))
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                animateReaction()
            }
    }
    
    private func animateReaction() {
        withAnimation(.easeOut(duration: 2)) {
            offset = -200
            opacity = 0
        }
    }
}

/// Model for animating reactions
struct AnimatingReaction: Identifiable {
    let id: UUID
    let emoji: String
}

/// View for displaying recent reactions from friends
struct RecentReactionsView: View {
    @ObservedObject var viewModel: LiveWorkoutViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friends Reacting")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.recentReactions.isEmpty {
                Text("No reactions yet. Crush it! 💪")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentReactions.prefix(10), id: \.id) { reaction in
                        HStack(spacing: 8) {
                            Text(reaction.emoji)
                                .font(.system(size: 20))
                            
                            if let user = reaction.user {
                                Text(user.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(timeAgo(from: reaction.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground))
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(seconds / 3600)
            return "\(hours)h"
        }
    }
}

/// Floating reactions particle effect (for more dramatic effect)
struct FloatingReactionsParticleView: View {
    @State private var particles: [ReactionParticle] = []
    
    let onReactionTapped: (String) -> Void
    
    private let allowedEmojis = ["💪", "🔥", "👏", "🎯", "😤"]
    
    var body: some View {
        ZStack {
            // Particles
            ForEach(particles, id: \.id) { particle in
                Text(particle.emoji)
                    .font(.system(size: CGFloat(particle.size)))
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func addReaction(_ emoji: String) {
        var newParticles: [ReactionParticle] = []
        
        for _ in 0..<3 {
            let angle = Double.random(in: 0...(2 * .pi))
            let velocity = Double.random(in: 50...150)
            
            var particle = ReactionParticle(emoji: emoji)
            particle.vx = cos(angle) * velocity
            particle.vy = sin(angle) * velocity
            
            newParticles.append(particle)
        }
        
        particles.append(contentsOf: newParticles)
        
        // Animate particles
        for (index, particle) in newParticles.enumerated() {
            withAnimation(.easeOut(duration: 2)) {
                if let idx = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[idx].x = particle.vx
                    particles[idx].y = particle.vy
                    particles[idx].opacity = 0
                }
            }
        }
        
        // Remove particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            particles.removeAll { p in
                newParticles.contains { $0.id == p.id }
            }
        }
    }
}

/// Particle model for reactions
struct ReactionParticle: Identifiable {
    let id = UUID()
    let emoji: String
    var x: CGFloat = 0
    var y: CGFloat = 0
    var vx: Double = 0
    var vy: Double = 0
    var size: CGFloat = CGFloat.random(in: 24...36)
    var opacity: Double = 1
}

#Preview {
    LiveReactionView(reactions: []) { emoji in
        print("Reacted with: \(emoji)")
    }
}
