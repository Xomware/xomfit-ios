import SwiftUI

/// Name a gym and tick the equipment and branded machines it has.
struct GymEditorView: View {
    @State private var gym: GymProfile
    @Environment(\.dismiss) private var dismiss

    init(gym: GymProfile) {
        _gym = State(initialValue: gym)
    }

    private var seriesGroups: [(title: String, machines: [Machine])] {
        var order: [String] = []
        var groups: [String: [Machine]] = [:]
        for machine in MachineCatalog.all {
            let title = "\(machine.brand) \(machine.series) · \(machine.loading.displayName)"
            if groups[title] == nil { order.append(title) }
            groups[title, default: []].append(machine)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Carbon Performance", text: $gym.name)
                }
                Section("Equipment") {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Toggle(isOn: binding(\.equipment, equipment)) {
                            Label(equipment.displayName, systemImage: equipment.icon)
                        }
                    }
                }
                ForEach(seriesGroups, id: \.title) { group in
                    Section {
                        ForEach(group.machines) { machine in
                            Toggle(machine.name, isOn: binding(\.machineIds, machine.id))
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Button(allSelected(group.machines) ? "None" : "All") {
                                Haptics.light()
                                toggleAll(group.machines)
                            }
                            .font(Theme.fontCaption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .tint(Theme.accent)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(gym.name.isEmpty ? "New Gym" : gym.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        gym.name = gym.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        GymLibrary.shared.saveGym(gym)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(gym.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func binding<T: Hashable>(_ path: WritableKeyPath<GymProfile, Set<T>>, _ value: T) -> Binding<Bool> {
        Binding(
            get: { gym[keyPath: path].contains(value) },
            set: { isOn in
                if isOn { gym[keyPath: path].insert(value) } else { gym[keyPath: path].remove(value) }
            }
        )
    }

    private func allSelected(_ machines: [Machine]) -> Bool {
        machines.allSatisfy { gym.machineIds.contains($0.id) }
    }

    private func toggleAll(_ machines: [Machine]) {
        let ids = machines.map(\.id)
        if allSelected(machines) {
            gym.machineIds.subtract(ids)
        } else {
            gym.machineIds.formUnion(ids)
        }
    }
}
