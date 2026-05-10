import SwiftUI

@MainActor
@Observable
final class WorkoutBuilderViewModel {
    var name: String = ""
    var category: WorkoutTemplate.TemplateCategory = .custom
    var exercises: [WorkoutTemplate.TemplateExercise] = []
    var isSaving = false
    var errorMessage: String?

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
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
        exercises[index].notes = notes
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
}
