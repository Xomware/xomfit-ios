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
    
    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    
    // MARK: - Font Sizes
    static let fontTitle = Font.system(size: 28, weight: .bold)
    static let fontHeadline = Font.system(size: 20, weight: .semibold)
    static let fontBody = Font.system(size: 16, weight: .regular)
    static let fontCaption = Font.system(size: 13, weight: .regular)
    static let fontSmall = Font.system(size: 11, weight: .medium)
}

// MARK: - Card Modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
