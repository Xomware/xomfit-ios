import Foundation
import Observation

/// Per-user, on-device equipment state: the lifter's gyms, which one they are
/// at, and how each machine is set up.
///
/// UserDefaults rather than Supabase because there is no backend table for it,
/// and losing it on reinstall costs a lifter a few re-typed seat heights.
/// Stored as one blob per user so switching accounts on a device never mixes setups.
@MainActor
@Observable
final class GymLibrary {
    static let shared = GymLibrary()

    private(set) var gyms: [GymProfile] = []
    private(set) var activeGymId: String?
    private(set) var machineSettings: [String: MachineSettings] = [:]

    var activeGym: GymProfile? { gyms.first { $0.id == activeGymId } }

    private let defaults: UserDefaults
    private var userId: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Switches to `userId`'s saved state. Call whenever the signed-in user changes.
    func load(userId: String) {
        self.userId = userId
        let snapshot = defaults.data(forKey: Self.key(userId))
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        gyms = snapshot?.gyms ?? []
        activeGymId = snapshot?.activeGymId
        machineSettings = snapshot?.machineSettings ?? [:]
    }

    /// Inserts or replaces by id. The first gym saved becomes active.
    func saveGym(_ gym: GymProfile) {
        if let i = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[i] = gym
        } else {
            gyms.append(gym)
        }
        if activeGymId == nil { activeGymId = gym.id }
        save()
    }

    func deleteGym(id: String) {
        gyms.removeAll { $0.id == id }
        if activeGymId == id { activeGymId = nil }
        save()
    }

    /// Pass nil to train with no gym filter.
    func setActiveGym(id: String?) {
        activeGymId = id
        save()
    }

    /// Machines to offer when logging an exercise: the active gym's if it has
    /// any for this lift, otherwise the whole catalog — gym lists are often
    /// incomplete, and hiding a machine the lifter is standing at is worse.
    func machineOptions(for exerciseId: String) -> [Machine] {
        let atGym = activeGym?.machines(for: exerciseId) ?? []
        return atGym.isEmpty ? MachineCatalog.machines(for: exerciseId) : atGym
    }

    func settings(for machineId: String) -> MachineSettings {
        machineSettings[machineId] ?? MachineSettings()
    }

    func setSettings(_ settings: MachineSettings, for machineId: String) {
        machineSettings[machineId] = settings == MachineSettings() ? nil : settings
        save()
    }

    private func save() {
        guard let userId else { return }
        let snapshot = Snapshot(gyms: gyms, activeGymId: activeGymId, machineSettings: machineSettings)
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: Self.key(userId))
    }

    private static func key(_ userId: String) -> String { "xomfit_gym_library.\(userId)" }

    private struct Snapshot: Codable {
        var gyms: [GymProfile]
        var activeGymId: String?
        var machineSettings: [String: MachineSettings]
    }
}
