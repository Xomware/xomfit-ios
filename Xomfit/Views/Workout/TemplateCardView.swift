import SwiftUI

struct TemplateCardView: View {
    let template: WorkoutTemplate
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Category icon
                Image(systemName: template.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("\(template.exercises.count) ex")
                        Text("~\(template.estimatedDuration)m")
                            .foregroundStyle(Theme.accent)
                    }
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 160, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name) template, \(template.exercises.count) exercises, about \(template.estimatedDuration) minutes")
        .accessibilityAddTraits(.isButton)
    }
}
