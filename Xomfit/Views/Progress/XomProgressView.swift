import SwiftUI

struct XomProgressView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text("Progress")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
