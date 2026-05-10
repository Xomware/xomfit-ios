import SwiftUI

/// Layout style for `TemplateCardView`.
///
/// `.compact` keeps the legacy fixed-width card used inside horizontal carousels.
/// `.row` expands to fill its container, intended for vertical lists.
enum TemplateCardStyle {
    case compact
    case row
}

struct TemplateCardView: View {
    let template: WorkoutTemplate
    var style: TemplateCardStyle = .compact

    /// Tap handler. When `nil`, the card renders as plain visual content with no
    /// embedded Button -- intended for cases where the parent wraps this view in
    /// a `NavigationLink` (or similar) and needs the inner content to NOT consume
    /// taps.
    let onSelect: (() -> Void)?

    init(template: WorkoutTemplate, style: TemplateCardStyle = .compact, onSelect: (() -> Void)? = nil) {
        self.template = template
        self.style = style
        self.onSelect = onSelect
    }

    var body: some View {
        if let onSelect {
            Button(action: {
                Haptics.light()
                onSelect()
            }) {
                cardContent
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("\(template.name) template, \(template.exercises.count) exercises, about \(template.estimatedDuration) minutes")
            .accessibilityAddTraits(.isButton)
        } else {
            cardContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(template.name) template, \(template.exercises.count) exercises, about \(template.estimatedDuration) minutes")
        }
    }

    private var cardContent: some View {
        HStack(spacing: 10) {
            // Category icon
            Image(systemName: template.category.icon)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(style == .row ? .subheadline.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(template.exercises.count) ex")
                    Text("~\(template.estimatedDuration)m")
                        .foregroundStyle(Theme.accent)
                    if style == .row && !template.description.isEmpty {
                        Text("•")
                            .foregroundStyle(Theme.textTertiary)
                        Text(template.description)
                            .lineLimit(1)
                    }
                }
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            }

            if style == .row {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: style == .row ? .infinity : nil, alignment: .leading)
        .frame(width: style == .row ? nil : 160, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
