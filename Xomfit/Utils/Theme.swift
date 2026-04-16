import CoreHaptics
import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // MARK: - Colors (neutral near-black ramp, single accent, role-split semantics)

    /// 60% — App background. Warm-neutral near-black, removes blue cast.
    static let background        = Color(hex: "0B0B0E")
    /// 30% — Cards. Pure luminance lift from background, same hue family.
    static let surface           = Color(hex: "17171C")
    /// Sheets / modals / elevated containers.
    static let surfaceElevated   = Color(hex: "1F1F26")
    /// DEPRECATED alias — keep for one release, migrate callers, then remove.
    static let surfaceSecondary  = Color(hex: "1F1F26")

    /// 10% — Primary accent (CTAs, selected states only). Desaturated from 33FF66.
    static let accent            = Color(hex: "2FE562")
    /// Tinted fill for accent-utility use (selected tab bg, accent chip bg).
    static let accentMuted       = Color(hex: "2FE562").opacity(0.18)

    /// Text — off-white, neutral greys (not blue-greys).
    static let textPrimary       = Color(hex: "F5F5F7")
    static let textSecondary     = Color(hex: "9A9AA3")
    static let textTertiary      = Color(hex: "6B6B72")

    /// Semantic colors — all desaturated a notch vs prior values.
    static let prGold            = Color(hex: "F5C84B")
    static let milestone         = Color(hex: "9B7BFF")
    static let streak            = Color(hex: "FF7A45")
    static let alert             = Color(hex: "FF8A4C")
    static let destructive       = Color(hex: "FF5E5E")
    /// Kept for API compat; points to accent. Callers should migrate to `accent`.
    static let energy            = accent

    // MARK: - Hairlines

    static let hairline          = Color.white.opacity(0.08)
    static let hairlineStrong    = Color.white.opacity(0.12)

    // Glass morphism — kept for callsite compat; prefer hairline tokens going forward
    static let glassFill         = Color.white.opacity(0.04)
    static let glassBorder       = Color.white.opacity(0.08)
    static let glassHighlight    = Color.white.opacity(0.12)

    // MARK: - Activity badge tokens

    static let badgeWorkout      = accent
    static let badgePR           = prGold
    static let badgeMilestone    = milestone
    static let badgeStreak       = streak

    // MARK: - Spacing (8pt grid + section rhythm)

    enum Spacing {
        static let hairline: CGFloat = 0.5
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
        static let section: CGFloat = 40
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
    }

    /// DEPRECATED — use Radius.md
    static let cornerRadius      = Radius.md
    /// DEPRECATED — use Radius.sm
    static let cornerRadiusSmall = Radius.sm

    // Legacy spacing aliases (prefer Spacing.*)
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // MARK: - Typography

    /// Hero display number — PRs, volume totals, hero metrics.
    static let fontDisplay: Font = .system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()
    /// Secondary hero number — stat columns, card titles with numbers.
    static let fontNumberLarge: Font = .system(size: 28, weight: .bold, design: .rounded).monospacedDigit()
    /// Inline numbers — set rows, feed stat pills.
    static let fontNumberMedium: Font = .system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()

    static let fontLargeTitle: Font  = .largeTitle.weight(.bold)
    static let fontTitle: Font       = .title.weight(.bold)
    static let fontTitle2: Font      = .title2.weight(.semibold)
    static let fontHeadline: Font    = .title3.weight(.semibold)
    static let fontBody: Font        = .body
    static let fontSubheadline: Font = .subheadline
    static let fontCaption: Font     = .caption
    static let fontSmall: Font       = .caption2.weight(.medium)

    /// Uppercase + 0.5 kerning metric label. Apply via XomMetricLabel or .metricLabel() modifier.
    static let fontMetricLabel: Font = .caption.weight(.semibold)
}

// MARK: - Animation Tokens

extension Animation {
    /// Navigation transitions, modals appearing
    static let xomConfident = Animation.easeOut(duration: 0.2)
    /// Buttons, toggles, interactive cards
    static let xomPlayful = Animation.spring(dampingFraction: 0.6)
    /// Background state changes, tab switches
    static let xomChill = Animation.easeInOut(duration: 0.4)
    /// Press feedback, tap acknowledgment
    static let xomSnappy = Animation.snappy(duration: 0.18)
    /// PR achieved, badge unlocked, streak milestone
    static let xomCelebration = Animation.spring(response: 0.3, dampingFraction: 0.5)
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Custom Patterns (CoreHaptics)

    /// Ascending burst for PR celebration — builds up then hits hard
    static func prCelebration() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0.1),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ], relativeTime: 0.2),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0.35),
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }

    /// Satisfying completion pattern for finishing a workout
    static func workoutComplete() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0, duration: 0.2),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.3),
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }

    /// Quick double tap for streak milestone or leaderboard rank up
    static func rankUp() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.12),
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - Glass Card Modifier (kept for callsite compat)

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(GlassCardStyle())
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }

    func glassStyle() -> some View {
        self
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

// MARK: - Shimmer Modifier (soft diagonal sweep)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.06), .clear],
                    startPoint: .init(x: phase - 0.5, y: phase - 0.5),
                    endPoint: .init(x: phase + 0.5, y: phase + 0.5)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var height: CGFloat = 80

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(Theme.surface)
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Staggered Appearance

struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Button Styles (legacy — prefer XomButton)

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.accent)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.xomSnappy, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.xomSnappy, value: configuration.isPressed)
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.xomSnappy, value: configuration.isPressed)
    }
}
