import SwiftUI

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let scale: CGFloat
    let symbol: String
}

// MARK: - Particle Burst View

/// Fires a burst of particles outward from the center on `trigger` changes.
/// Particles animate out and fade over `duration` seconds then disappear.
/// Usage: overlay this on the button/view and bind `trigger` to a Bool that flips on burst.
struct ParticleBurstView: View {
    /// Flip this Bool (false → true) to trigger a burst.
    let trigger: Bool

    /// Symbols to randomly sample from.
    var symbols: [String] = ["heart.fill"]

    /// Color of the burst particles.
    var color: Color = Theme.destructive

    /// Number of particles to emit.
    var count: Int = 8

    /// Duration of the burst animation in seconds.
    var duration: Double = 0.6

    @State private var particles: [Particle] = []
    @State private var isAnimating = false

    /// Suppresses the burst entirely when Reduce Motion is enabled.
    /// Callsites can still gate as a belt-and-suspenders, but this guarantees
    /// any future caller respects the preference automatically.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ParticleView(
                    particle: particle,
                    color: color,
                    isAnimating: isAnimating,
                    duration: duration
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, newValue in
            guard newValue, !reduceMotion else { return }
            burst()
        }
    }

    private func burst() {
        particles = (0..<count).map { i in
            Particle(
                angle: Double(i) / Double(count) * 360,
                distance: CGFloat.random(in: 20...44),
                scale: CGFloat.random(in: 0.6...1.0),
                symbol: symbols.randomElement() ?? "heart.fill"
            )
        }
        isAnimating = false
        // Short delay lets SwiftUI render particles at origin before animating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(.easeOut(duration: duration)) {
                isAnimating = true
            }
        }
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            particles = []
            isAnimating = false
        }
    }
}

// MARK: - Single Particle

private struct ParticleView: View {
    let particle: Particle
    let color: Color
    let isAnimating: Bool
    let duration: Double

    private var offsetX: CGFloat {
        isAnimating ? cos(particle.angle * .pi / 180) * particle.distance : 0
    }
    private var offsetY: CGFloat {
        isAnimating ? sin(particle.angle * .pi / 180) * particle.distance : 0
    }

    var body: some View {
        Image(systemName: particle.symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .scaleEffect(isAnimating ? particle.scale : 0.1)
            .offset(x: offsetX, y: offsetY)
            .opacity(isAnimating ? 0 : 1)
            .animation(.easeOut(duration: duration), value: isAnimating)
    }
}
