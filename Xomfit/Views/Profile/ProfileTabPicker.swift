import SwiftUI

struct ProfileTabPicker: View {
    @Binding var selectedTab: ProfileTab
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { tab in
                Button {
                    withAnimation(.xomConfident) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: tab.icon)
                            .font(.headline)
                            .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.textSecondary)
                            .frame(height: 24)

                        Text(tab.label)
                            .font(Theme.fontSmall)
                            .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.textSecondary)
                    }
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Theme.accent)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.label) tab")
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .overlay(alignment: .bottom) {
            Divider()
                .background(Theme.textSecondary.opacity(0.3))
        }
    }
}
