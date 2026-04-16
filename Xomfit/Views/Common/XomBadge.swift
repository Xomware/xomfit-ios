import SwiftUI

// MARK: - XomBadge Variant

enum XomBadgeVariant {
    /// Static display pill — color stripe + icon + label.
    case display
    /// Selectable chip — accent fill when active, surface + hairline when inactive.
    case interactive
    /// Subtle secondary pill — surfaceElevated fill, textSecondary label.
    case secondary
}

// MARK: - XomBadge

struct XomBadge: View {
    let label: String
    let icon: String?
    let color: Color
    let variant: XomBadgeVariant
    let isActive: Bool

    init(
        _ label: String,
        icon: String? = nil,
        color: Color = Theme.accent,
        variant: XomBadgeVariant = .display,
        isActive: Bool = false
    ) {
        self.label = label
        self.icon = icon
        self.color = color
        self.variant = variant
        self.isActive = isActive
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(labelForeground)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundFill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
    }

    // MARK: Computed colors

    private var iconForeground: Color {
        switch variant {
        case .display:     color
        case .interactive: isActive ? .black : Theme.textSecondary
        case .secondary:   Theme.textSecondary
        }
    }

    private var labelForeground: Color {
        switch variant {
        case .display:     Theme.textPrimary
        case .interactive: isActive ? .black : Theme.textSecondary
        case .secondary:   Theme.textSecondary
        }
    }

    private var backgroundFill: Color {
        switch variant {
        case .display:     color.opacity(0.15)
        case .interactive: isActive ? Theme.accent : Theme.surface
        case .secondary:   Theme.surfaceElevated
        }
    }

    private var borderColor: Color {
        switch variant {
        case .display:     color.opacity(0.3)
        case .interactive: isActive ? Color.clear : Theme.hairline
        case .secondary:   Theme.hairline
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack {
            XomBadge("Workout", icon: "dumbbell.fill", color: Theme.accent, variant: .display)
            XomBadge("PR", icon: "trophy.fill", color: Theme.prGold, variant: .display)
            XomBadge("Milestone", icon: "star.fill", color: Theme.milestone, variant: .display)
            XomBadge("Streak", icon: "flame.fill", color: Theme.streak, variant: .display)
        }

        HStack {
            XomBadge("All", variant: .interactive, isActive: true)
            XomBadge("Workouts", variant: .interactive, isActive: false)
            XomBadge("PRs", variant: .interactive, isActive: false)
        }

        HStack {
            XomBadge("Private", icon: "lock.fill", variant: .secondary)
            XomBadge("Chest", variant: .secondary)
        }
    }
    .padding()
    .background(Theme.background)
}
