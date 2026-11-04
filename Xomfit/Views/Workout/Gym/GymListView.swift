import SwiftUI

/// The lifter's gyms. Tap one to train there; the generator only uses kit the
/// active gym has.
struct GymListView: View {
    private let library = GymLibrary.shared
    @State private var editing: GymProfile?

    var body: some View {
        List {
            Section {
                row(name: "Anywhere", detail: "No equipment filter", isActive: library.activeGymId == nil) {
                    library.setActiveGym(id: nil)
                }
                ForEach(library.gyms) { gym in
                    row(name: gym.name, detail: detail(gym), isActive: library.activeGymId == gym.id) {
                        library.setActiveGym(id: gym.id)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { library.deleteGym(id: gym.id) }
                        Button("Edit") { editing = gym }.tint(Theme.accent)
                    }
                }
            } footer: {
                Text("Swipe a gym to edit its equipment.")
            }

            Section {
                Button {
                    Haptics.light()
                    editing = GymProfile(name: "")
                } label: {
                    Label("Add Gym", systemImage: "plus")
                }
                .foregroundStyle(Theme.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Gyms")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { gym in
            GymEditorView(gym: gym)
        }
    }

    private func row(name: String, detail: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Theme.fontBodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func detail(_ gym: GymProfile) -> String {
        let kit = Equipment.allCases.filter(gym.equipment.contains).map(\.displayName)
        let machines = gym.machineIds.count
        return (kit + (machines > 0 ? ["\(machines) machines"] : [])).joined(separator: " · ")
    }
}
