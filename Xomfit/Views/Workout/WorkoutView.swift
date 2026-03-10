import SwiftUI

struct WorkoutView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text("Workout")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
            }
            .navigationTitle("Workout")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
