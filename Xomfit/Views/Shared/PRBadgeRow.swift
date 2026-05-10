import SwiftUI

struct PRBadgeRow: View {
    let pr: PersonalRecord

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(Theme.prGold)
                .font(Theme.fontSubheadline)
                .frame(width: 20)

            Text(pr.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(pr.weight.formattedWeight) \u{00D7} \(pr.reps)")
                .font(Theme.fontNumberMedium)
                .foregroundStyle(Theme.textPrimary)

            if let imp = pr.improvementString {
                Text(imp)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.prGold)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pr.exerciseName), \(pr.weight.formattedWeight) pounds for \(pr.reps) reps\(pr.improvementString.map { ", \($0)" } ?? "")")
    }
}
