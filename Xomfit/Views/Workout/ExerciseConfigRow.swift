import SwiftUI

/// Horizontally scrollable rows of config pills for grip, attachment, position, and laterality.
/// Shared between ExerciseCard (list mode) and WorkoutFocusView (focus mode).
struct ExerciseConfigRow: View {
    let exercise: WorkoutExercise
    let onGripChanged: (GripType) -> Void
    let onAttachmentChanged: (CableAttachment) -> Void
    let onPositionChanged: (ExercisePosition) -> Void
    var onLateralityChanged: ((Laterality) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let grips = exercise.exercise.supportedGrips {
                configSection(label: "Grip") {
                    ForEach(grips) { grip in
                        configPill(
                            label: grip.displayName,
                            isSelected: exercise.selectedGrip == grip
                        ) { onGripChanged(grip) }
                    }
                }
            }
            if let attachments = exercise.exercise.supportedAttachments {
                configSection(label: "Attachment") {
                    ForEach(attachments) { attachment in
                        configPill(
                            label: attachment.displayName,
                            isSelected: exercise.selectedAttachment == attachment
                        ) { onAttachmentChanged(attachment) }
                    }
                }
            }
            if let positions = exercise.exercise.supportedPositions {
                configSection(label: "Position") {
                    ForEach(positions) { position in
                        configPill(
                            label: position.displayName,
                            isSelected: exercise.selectedPosition == position
                        ) { onPositionChanged(position) }
                    }
                }
            }
            if exercise.exercise.supportsUnilateral, let lateralityHandler = onLateralityChanged {
                configSection(label: "Laterality") {
                    ForEach(Laterality.allCases) { lat in
                        configPill(
                            label: lat.displayName,
                            isSelected: exercise.selectedLaterality == lat
                        ) { lateralityHandler(lat) }
                    }
                }
            }
        }
    }

    private func configSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                content()
            }
        }
    }

    private func configPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Theme.accent : Theme.surfaceSecondary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isSelected ? ", selected" : "")")
    }
}
