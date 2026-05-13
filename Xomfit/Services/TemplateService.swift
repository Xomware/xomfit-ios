import Foundation

@MainActor
final class TemplateService {
    static let shared = TemplateService()

    private let key = "xomfit_custom_templates"

    private init() {}

    // MARK: - Public

    func allTemplates() -> [WorkoutTemplate] {
        let custom = loadCustom()
        let all = WorkoutTemplate.builtIn + custom
        return all.sorted { lhs, rhs in
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.name < rhs.name
        }
    }

    func saveCustomTemplate(_ template: WorkoutTemplate) {
        var custom = loadCustom()
        var t = template
        t.isCustom = true
        if let idx = custom.firstIndex(where: { $0.id == t.id }) {
            custom[idx] = t
        } else {
            custom.append(t)
        }
        encode(custom)
    }

    func deleteCustomTemplate(id: String) {
        var custom = loadCustom()
        custom.removeAll { $0.id == id }
        encode(custom)
    }

    // MARK: - Private

    private func loadCustom() -> [WorkoutTemplate] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WorkoutTemplate].self, from: data)) ?? []
    }

    private func encode(_ templates: [WorkoutTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Debug Fixtures (#353)

    #if DEBUG
    /// Hydrates the custom-templates cache with `WorkoutTemplate.mockFixtures`.
    /// Only invoked when `XOMFIT_AUTH_BYPASS=1` from `AuthService` so future
    /// agents can screenshot the templates list / builder without real data.
    /// Safe to call repeatedly — overwrites the custom-template cache.
    func seedDebugFixtures() {
        encode(WorkoutTemplate.mockFixtures)
    }
    #endif
}
