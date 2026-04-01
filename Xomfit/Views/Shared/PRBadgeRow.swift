import SwiftUI

struct PRBadgeRow: View {
    let pr: PersonalRecord

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundStyle(Theme.prGold)
                .font(.subheadline)

            Text(pr.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text("\(pr.weight.formattedWeight) \u{00D7} \(pr.reps)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)

            if let imp = pr.improvementString {
                Text(imp)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.prGold)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pr.exerciseName), \(pr.weight.formattedWeight) pounds for \(pr.reps) reps\(pr.improvementString.map { ", \($0)" } ?? "")")
    }
}
