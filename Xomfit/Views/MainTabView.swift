import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: FeedView()
                case 1: WorkoutView()
                case 2: XomProgressView()
                case 3: ProfileView()
                default: FeedView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            FloatingTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Feed"),
        ("dumbbell.fill", "Workout"),
        ("chart.line.uptrend.xyaxis", "Progress"),
        ("person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: selectedTab == index ? 22 : 20))
                            .symbolEffect(.bounce, value: selectedTab == index)

                        Text(tabs[index].label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == index ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel(tabs[index].label)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
                .strokeBorder(Theme.glassBorder, lineWidth: 0.5)
            )
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
