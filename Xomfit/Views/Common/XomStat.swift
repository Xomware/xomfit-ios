import SwiftUI

struct XomStat: View {
    let value: String
    let label: String
    let icon: String?
    let iconColor: Color

    init(_ value: String, label: String, icon: String? = nil, iconColor: Color = Theme.accent) {
        self.value = value
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
