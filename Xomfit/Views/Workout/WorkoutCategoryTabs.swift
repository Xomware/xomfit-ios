import SwiftUI

/// Segmented control used at the top of the Workouts tab (#338).
///
/// Drives the inline `WorkoutCategoryListView` below the CTAs by exposing a
/// `WorkoutCategory` binding. Kept as a thin wrapper around `Picker` so we can
/// swap to a paged `TabView` later if we want without touching call sites.
struct WorkoutCategoryTabs: View {
    @Binding var selection: WorkoutCategory

    var body: some View {
        Picker("Workout category", selection: $selection) {
            ForEach(WorkoutCategory.allCases) { category in
                Text(category.title)
                    .tag(category)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.md)
        .accessibilityLabel("Workout category")
        .accessibilityHint("Switches between recents, your workouts, saved or friends workouts, and pre-generated templates")
    }
}

#Preview {
    @Previewable @State var selection: WorkoutCategory = .recents
    return ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            WorkoutCategoryTabs(selection: $selection)
            Spacer()
        }
    }
}
