import SwiftUI

/// The chosen machine and its saved setup on one line, tappable to edit the setup.
///
/// List-mode cards keep `ExerciseConfigRow` behind a disclosure, which hid the
/// one thing a lifter needs walking up to the machine: which one, and where the
/// seat goes.
struct MachineSummaryButton: View {
    let machine: Machine

    @State private var isEditing = false

    var body: some View {
        // Brand + name is how lifters refer to the machine; series names are
        // catalog filing, and no two Arsenal machines share a name.
        let title = "\(machine.brand) \(machine.name)"
        let summary = GymLibrary.shared.settings(for: machine.id).summary
        Button {
            Haptics.selection()
            isEditing = true
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: summary == nil ? "plus" : "slider.horizontal.3")
                Text("\(title) · \(summary ?? "Add setup")")
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(summary == nil ? Theme.textSecondary : Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.tight)
            .background(Theme.surfaceSecondary)
            .clipShape(.capsule)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(title). \(summary.map { "Setup: \($0)" } ?? "No setup saved")")
        .accessibilityHint("Edits seat, pad and handle settings")
        .sheet(isPresented: $isEditing) {
            MachineSettingsSheet(machine: machine)
                .presentationDetents([.medium, .large])
        }
    }
}
