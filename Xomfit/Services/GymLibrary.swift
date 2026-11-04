import Foundation
import Observation

/// Per-user, on-device equipment state: how each machine is set up.
///
/// UserDefaults rather than Supabase because there is no backend table for it,
/// and losing it on reinstall costs a lifter a few re-typed seat heights.
/// Stored as one blob per user so switching accounts on a device never mixes setups.
@MainActor
@Observable
final class GymLibrary {
    static let shared = GymLibrary()

    private(set) var machineSettings: [String: MachineSettings] = [:]

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
        machineSettings = snapshot?.machineSettings ?? [:]
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
        let snapshot = Snapshot(machineSettings: machineSettings)
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: Self.key(userId))
    }

    private static func key(_ userId: String) -> String { "xomfit_gym_library.\(userId)" }

    private struct Snapshot: Codable {
        var machineSettings: [String: MachineSettings]
    }
}
