import SwiftUI

enum Theme {
    // MARK: - Colors
    static let accent = Color(hex: "33FF66")
    static let background = Color(hex: "0A0A0F")
    static let cardBackground = Color(hex: "1A1A2E")
    static let secondaryBackground = Color(hex: "16213E")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "999999")
    static let destructive = Color(hex: "FF4444")
    static let warning = Color(hex: "FFD700")
    static let prGold = Color(hex: "FFD700")

    // Glass / surface colors
    static let glassFill = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.15)

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 10

    // MARK: - Typography
    static let fontDisplay = Font.system(size: 36, weight: .black, design: .rounded)
    static let fontLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let fontTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let fontHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let fontBody = Font.system(size: 16, weight: .regular)
    static let fontCaption = Font.system(size: 13, weight: .regular)
    static let fontSmall = Font.system(size: 11, weight: .medium)
}

// MARK: - Glass Card Modifier

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.cardBackground)
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
            .fill(Theme.cardBackground)
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

// MARK: - Pressable Card Style

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
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

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Button Styles

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .shadow(
                color: Theme.accent.opacity(0.3),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
