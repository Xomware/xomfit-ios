import SwiftUI

struct TemplateCardView: View {
    let template: WorkoutTemplate
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                // Category icon
                Image(systemName: template.category.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

                Spacer(minLength: 4)

                // Name
                Text(template.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                // Details
                HStack(spacing: 4) {
                    Text("\(template.exercises.count) exercises")
                    Text("~\(template.estimatedDuration)m")
                        .foregroundStyle(Theme.accent)
                }
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.paddingMedium)
            .frame(width: 160, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name) template, \(template.exercises.count) exercises, about \(template.estimatedDuration) minutes")
        .accessibilityAddTraits(.isButton)
    }
}
