import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // MARK: - Colors (60-30-10 rule)

    /// 10% — Brand accent (CTAs, selected states, links)
    static let accent = Color(hex: "33FF66")
    /// 60% — Primary background
    static let background = Color(hex: "0A0A0F")
    /// 30% — Cards, modals, sheets
    static let surface = Color(hex: "1A1A2E")
    /// Deeper surface for nested containers
    static let surfaceSecondary = Color(hex: "16213E")
    /// Workout start, PRs, success states
    static let energy = Color(hex: "00C46A")
    /// Calories, heart rate zones, warnings
    static let alert = Color(hex: "FF6B35")
    /// Delete, destructive actions
    static let destructive = Color(hex: "FF4444")
    /// PR badges, streaks
    static let prGold = Color(hex: "FFD700")

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "9CA3AF")

    // Glass morphism
    static let glassFill = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.15)

    // Activity badge colors
    static let badgeWorkout = accent
    static let badgePR = prGold
    static let badgeMilestone = Color(hex: "AA66FF")
    static let badgeStreak = Color(hex: "FF6633")

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 10

    // Legacy spacing aliases (prefer Spacing.*)
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // MARK: - Typography (Dynamic Type — never hard-code sizes)

    /// Hero numbers: PRs, distances, big stats
    static let fontDisplay: Font = .largeTitle.weight(.black).width(.condensed)
    /// Screen titles
    static let fontLargeTitle: Font = .largeTitle.weight(.bold)
    /// Section titles, card headlines
    static let fontTitle: Font = .title.weight(.bold)
    /// Card titles, emphasized labels
    static let fontHeadline: Font = .title3.weight(.semibold)
    /// Body text, descriptions, feed text
    static let fontBody: Font = .body
    /// Secondary info, workout types
    static let fontSubheadline: Font = .subheadline
    /// Timestamps, metadata, labels
    static let fontCaption: Font = .caption
    /// Micro-labels, badges
    static let fontSmall: Font = .caption2.weight(.medium)
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
}

// MARK: - Glass Card Modifier

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.glassBorder, lineWidth: 0.5)
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
            .background(Theme.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .strokeBorder(Theme.glassBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.1), .clear],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
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

// MARK: - Button Styles

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .shadow(
                color: Theme.accent.opacity(0.3),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
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
            .background(Theme.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
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
