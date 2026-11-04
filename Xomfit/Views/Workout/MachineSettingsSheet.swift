import SwiftUI

/// Edits the lifter's remembered setup for one machine.
struct MachineSettingsSheet: View {
    let machine: Machine

    @Environment(\.dismiss) private var dismiss
    @State private var settings = MachineSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Seat height", text: $settings.seat)
                    field("Pad position", text: $settings.pad)
                    field("Pin / handles", text: $settings.handles)
                } footer: {
                    Text("Saved on this device and shown whenever this machine comes up.")
                }
                Section("Notes") {
                    TextField("Anything else — range limiter, foot position…", text: $settings.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(machine.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        GymLibrary.shared.setSettings(trimmed(settings), for: machine.id)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .tint(Theme.accent)
        }
        .onAppear { settings = GymLibrary.shared.settings(for: machine.id) }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("—", text: text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func trimmed(_ s: MachineSettings) -> MachineSettings {
        func t(_ v: String) -> String { v.trimmingCharacters(in: .whitespacesAndNewlines) }
        return MachineSettings(seat: t(s.seat), pad: t(s.pad), handles: t(s.handles), notes: t(s.notes))
    }
}
