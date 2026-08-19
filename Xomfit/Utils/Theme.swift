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

    // Strengthened: a dense set table relies on rules to separate rows, and at
    // 0.08 they were invisible against the card. These now actually read.
    static let hairline          = Color.white.opacity(0.11)
    static let hairlineStrong    = Color.white.opacity(0.18)

    /// Alternating row tint for set tables. Barely-there on purpose — it should
    /// register as banding, not as stripes.
    static let rowAlternate      = Color.white.opacity(0.025)
    /// Fill for a completed set row.
    static let rowCompleted      = Color(hex: "2FE562").opacity(0.09)

    // Glass morphism — kept for callsite compat; prefer hairline tokens going forward
    static let glassFill         = Color.white.opacity(0.04)
    static let glassBorder       = Color.white.opacity(0.08)
    static let glassHighlight    = Color.white.opacity(0.12)

    // MARK: - Activity badge tokens

    static let badgeWorkout      = accent
    static let badgePR           = prGold
    static let badgeMilestone    = milestone
    static let badgeStreak       = streak

    // MARK: - Spacing (4pt grid, tightened for density)
    //
    // Tightened across the board so more of a workout fits on screen at once.
    // A lifter mid-set is scanning for their next number, not reading a page —
    // generous whitespace costs them a scroll per exercise. Token *names* are
    // unchanged so every existing call site inherits the new density; the values
    // are what carry the redesign.

    enum Spacing {
        static let hairline: CGFloat = 0.5
        static let tighter: CGFloat = 2
        static let tight:   CGFloat = 4
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 6
        static let md:  CGFloat = 12
        /// Padding *inside* a card or panel. Deliberately larger than `md`:
        /// cards should breathe while the list between them stays dense, and
        /// reusing `md` for both made everything read uniformly cramped.
        static let card: CGFloat = 16
        static let lg:  CGFloat = 18
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 36
        static let section: CGFloat = 28
    }

    // MARK: - Corner Radius
    //
    // Tighter corners read as tool rather than toy. Large radii make dense rows
    // look like unrelated bubbles instead of a continuous table.

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
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

    // Numbers are the content in a lifting app, so every numeric token is
    // monospaced-digit: a column of weights that shifts horizontally as the
    // digits change is the single most amateur-looking thing a tracker can do.
    // Sizes are pulled down from the previous scale — the old 44pt display and
    // 28pt secondary were magazine-sized for what is a data table.

    /// Hero display number — PRs, volume totals, hero metrics.
    static let fontDisplay: Font = .system(size: 34, weight: .heavy, design: .rounded).monospacedDigit()
    /// Secondary hero number — stat columns, card titles with numbers.
    static let fontNumberLarge: Font = .system(size: 22, weight: .bold, design: .rounded).monospacedDigit()
    /// Inline numbers — set rows, feed stat pills.
    static let fontNumberMedium: Font = .system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    /// Set-table cells. Not rounded — a table wants a neutral, tabular face.
    static let fontTableNumber: Font = .system(size: 15, weight: .semibold).monospacedDigit()
    /// The greyed "what you did last time" column.
    static let fontTablePrevious: Font = .system(size: 13, weight: .regular).monospacedDigit()

    static let fontLargeTitle: Font  = .system(size: 28, weight: .bold)
    static let fontTitle: Font       = .system(size: 22, weight: .bold)
    static let fontTitle2: Font      = .system(size: 19, weight: .semibold)
    static let fontTitle3: Font      = .system(size: 17, weight: .semibold)
    static let fontHeadline: Font    = .system(size: 15, weight: .bold)
    static let fontBody: Font        = .system(size: 15)
    static let fontBodyEmphasized: Font = .system(size: 15, weight: .semibold)
    static let fontCallout: Font     = .system(size: 14)
    static let fontFootnote: Font    = .system(size: 13)
    static let fontSubheadline: Font = .system(size: 14, weight: .medium)
    static let fontCaption: Font     = .system(size: 12)
    static let fontCaption2: Font    = .system(size: 11)
    static let fontSmall: Font       = .system(size: 11, weight: .medium)

    /// Uppercase + kerned section label — the small-caps header that separates
    /// blocks in a dense layout without spending a full heading's worth of space.
    static let fontMetricLabel: Font = .system(size: 11, weight: .bold)
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

// Both styles lost their gradient/glow and a chunk of vertical padding. The
// sheen read as consumer-app polish; a training tool wants flat, high-contrast
// controls that do not compete with the numbers around them.

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontBodyEmphasized.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.accent, in: .rect(cornerRadius: Theme.Radius.md))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.xomSnappy, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.fontBodyEmphasized.weight(.bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.xomSnappy, value: configuration.isPressed)
    }
}

// MARK: - Section label

/// Small-caps section header. In a dense layout a full heading costs more
/// vertical space than the content it introduces, so blocks are separated by a
/// kerned uppercase label instead.
struct SectionLabel: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Theme.fontMetricLabel)
                .kerning(0.8)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(Theme.fontMetricLabel)
                    .kerning(0.8)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
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
