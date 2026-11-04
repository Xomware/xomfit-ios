import Foundation

/// A place the lifter trains and the kit it has. Named `GymProfile` because
/// `Gym` is already the check-in model.
///
/// `equipment` covers generic kit (barbells, a cable stack); `machineIds` names
/// specific branded machines. An exercise is available if either covers it, so
/// a gym with no generic `.machine` still gets its listed machines' lifts.
struct GymProfile: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var equipment: Set<Equipment> = [.barbell, .dumbbell, .cable, .bodyweight]
    var machineIds: Set<String> = []

    var machines: [Machine] { MachineCatalog.all.filter { machineIds.contains($0.id) } }

    /// Every exercise id one of this gym's machines can perform.
    var machineExerciseIds: Set<String> { Set(machines.flatMap(\.exerciseIds)) }

    func machines(for exerciseId: String) -> [Machine] {
        machines.filter { $0.exerciseIds.contains(exerciseId) }
    }
}
