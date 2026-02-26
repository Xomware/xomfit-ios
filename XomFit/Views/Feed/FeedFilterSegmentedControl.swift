import SwiftUI

struct FeedFilterSegmentedControl: View {
    @Binding var selectedFilter: FeedFilter
    
    var body: some View {
        Picker("Feed Filter", selection: $selectedFilter) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
    }
}

// MARK: - Custom Segmented Control Alternative

struct CustomFeedFilterControl: View {
    @Binding var selectedFilter: FeedFilter
    
    var body: some View {
        HStack(spacing: Theme.paddingSmall) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(
                                selectedFilter == filter ? .black : .gray
                            )
                        
                        if selectedFilter == filter {
                            Capsule()
                                .fill(Theme.accentColor)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "filterIndicator", in: nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.paddingSmall)
                .background(
                    selectedFilter == filter
                        ? Theme.accentColor.opacity(0.1)
                        : Color.clear
                )
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: Theme.paddingMedium) {
        FeedFilterSegmentedControl(
            selectedFilter: .constant(.friends)
        )
        
        CustomFeedFilterControl(
            selectedFilter: .constant(.following)
        )
    }
    .padding()
    .background(Theme.background)
}
