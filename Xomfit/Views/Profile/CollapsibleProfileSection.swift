import SwiftUI

/// A profile block that can be folded away.
///
/// The profile was one long column of a dozen analytics blocks, all expanded,
/// all the time — so reaching anything below the fold meant scrolling past
/// charts nobody had asked to see. Folding is remembered per section, because a
/// lifter who collapses volume trends means it every time, not once.
struct CollapsibleProfileSection<Content: View>: View {
    let title: String
    let systemImage: String
    /// Whether the section starts open the first time it is ever seen.
    let initiallyExpanded: Bool
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(
        title: String,
        systemImage: String,
        storageKey: String,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.initiallyExpanded = initiallyExpanded
        self.content = content
        _isExpanded = AppStorage(wrappedValue: initiallyExpanded, "profileSection.\(storageKey)")
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(.xomSnappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: Theme.Spacing.lg)

                    Text(title)
                        .font(Theme.fontHeadline)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses this section" : "Expands this section")

            if isExpanded {
                content()
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
