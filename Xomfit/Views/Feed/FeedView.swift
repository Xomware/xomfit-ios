import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text("Feed")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
            }
            .navigationTitle("Feed")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
