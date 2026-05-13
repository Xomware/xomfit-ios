import SwiftUI

@MainActor
@Observable
final class WorkoutBuilderViewModel {
    var name: String = ""
    var category: WorkoutTemplate.TemplateCategory = .custom
    var exercises: [WorkoutTemplate.TemplateExercise] = []
    var isSaving = false
    var errorMessage: String?

    /// Mirror of the UI-facing cap in `WorkoutBuilderView.nameMaxLength`.
    /// Kept in the view model so `isValid` stays the single source of truth for
    /// Save-button enablement (#319).
    static let nameMaxLength = 50

    var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard name.count <= Self.nameMaxLength else { return false }
        return !exercises.isEmpty
    }

    var estimatedDuration: Int {
        exercises.reduce(0) { $0 + $1.targetSets * 2 }
    }

    func addExercise(_ exercise: Exercise) {
        let templateExercise = WorkoutTemplate.TemplateExercise(
            id: UUID().uuidString,
            exercise: exercise,
            targetSets: 3,
            targetReps: "8-12",
            notes: nil
        )
        exercises.append(templateExercise)
    }

    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }

    func updateSets(at index: Int, sets: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].targetSets = max(1, sets)
    }

    func updateReps(at index: Int, reps: String) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].targetReps = reps
    }

    func updateNotes(at index: Int, notes: String?) {
        guard exercises.indices.contains(index) else { return }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        exercises[index].notes = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// Per-exercise rest override. Pass nil to fall back to the workout's global default.
    func updateRestSeconds(at index: Int, seconds: Int?) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].restSeconds = seconds
    }

    /// Builds a `WorkoutTemplate` from the current builder state without persisting.
    /// Use this when you want the template to drive an immediate workout (e.g.
    /// "Start Now") without committing it to saved templates.
    func buildTemplate() -> WorkoutTemplate {
        WorkoutTemplate(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            description: "\(exercises.count) exercises, ~\(estimatedDuration)min",
            exercises: exercises,
            estimatedDuration: estimatedDuration,
            category: category,
            isCustom: true
        )
    }

    /// Builds a template AND persists it via `TemplateService`. Returns the saved
    /// template so the caller can chain into Start Now if desired.
    @discardableResult
    func save() -> WorkoutTemplate {
        let template = buildTemplate()
        TemplateService.shared.saveCustomTemplate(template)
        return template
    }

    func loadTemplate(_ template: WorkoutTemplate) {
        name = template.name
        category = template.category
        exercises = template.exercises
    }

    // MARK: - Supersets (#344)

    /// Toggle a superset between `index` and the exercise immediately after it.
    /// - If `index` is already in a superset, the entire group is ungrouped.
    /// - Otherwise `index` and `index + 1` get a fresh shared group id.
    /// Mirrors `WorkoutLoggerViewModel.toggleSupersetWithNext` so builder and live
    /// workout share semantics.
    func toggleSupersetWithNext(at index: Int) {
        guard exercises.indices.contains(index) else { return }

        if let groupId = exercises[index].supersetGroupId {
            // Already in a group — ungroup all members of that group.
            for i in exercises.indices where exercises[i].supersetGroupId == groupId {
                exercises[i].supersetGroupId = nil
            }
            return
        }

        let nextIndex = index + 1
        guard exercises.indices.contains(nextIndex) else { return }
        let newGroupId = UUID()
        exercises[index].supersetGroupId = newGroupId
        exercises[nextIndex].supersetGroupId = newGroupId
    }

    /// Indices of all template exercises in the same superset group as `index`.
    /// Returns nil when `index` isn't part of a group.
    func supersetMembers(forExercise index: Int) -> [Int]? {
        guard exercises.indices.contains(index),
              let groupId = exercises[index].supersetGroupId else { return nil }
        return exercises.indices.filter { exercises[$0].supersetGroupId == groupId }
    }

    /// Letter label for the superset group `index` belongs to, in workout order
    /// of appearance ("A", "B", "C", ...). Returns nil when the exercise isn't in a group.
    func supersetLetter(forExercise index: Int) -> String? {
        guard exercises.indices.contains(index),
              let groupId = exercises[index].supersetGroupId else { return nil }
        let alphabet = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        var seen: [UUID: Int] = [:]
        var next = 0
        for ex in exercises {
            guard let gid = ex.supersetGroupId, seen[gid] == nil else { continue }
            seen[gid] = next
            next += 1
        }
        guard let pos = seen[groupId] else { return nil }
        return alphabet[pos % alphabet.count]
    }

    /// Whether `index` can currently be grouped with `index + 1` (i.e. the next
    /// exercise exists and isn't already in this exercise's group).
    func canGroupWithNext(at index: Int) -> Bool {
        guard exercises.indices.contains(index),
              exercises.indices.contains(index + 1) else { return false }
        let myGroup = exercises[index].supersetGroupId
        let nextGroup = exercises[index + 1].supersetGroupId
        return myGroup == nil || myGroup != nextGroup
    }
}
