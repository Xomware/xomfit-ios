import SwiftUI

/// "Do it for me": one tap on a region builds a workout from the active gym's
/// equipment and opens it ready to start.
struct QuickHitCard: View {
    let gymName: String?
    let onHit: (TrainingRegion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.accent)
                Text("Do it for me")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(gymName ?? "Any gym")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TrainingRegion.allCases) { region in
                    Button {
                        Haptics.medium()
                        onHit(region)
                    } label: {
                        VStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: region.icon)
                                .font(.title3)
                            Text("Hit \(region.displayName)")
                                .font(Theme.fontCaption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Theme.surfaceSecondary)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("Hit \(region.displayName)")
                    .accessibilityHint("Builds a \(region.displayName.lowercased()) workout from \(gymName ?? "any") equipment")
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }
}
