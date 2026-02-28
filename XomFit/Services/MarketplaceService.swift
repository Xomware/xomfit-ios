import Foundation
import Supabase

@MainActor
class MarketplaceService: ObservableObject {
    static let shared = MarketplaceService()

    private init() {}

    // MARK: - Programs

    /// Fetch paginated programs with optional filters
    func fetchPrograms(
        filter: MarketplaceFilter = .all,
        goal: ProgramGoal? = nil,
        difficulty: ProgramDifficulty? = nil,
        sortBy: MarketplaceSortOrder = .popular,
        searchQuery: String = "",
        page: Int = 0,
        pageSize: Int = 20
    ) async throws -> [WorkoutProgram] {
        var query = supabase
            .from("workout_programs")
            .select("*")
            .eq("is_public", value: true)

        // Filter
        switch filter {
        case .featured:
            query = query.eq("is_featured", value: true)
        case .free:
            query = query.eq("price", value: 0)
        case .new:
            let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 14))
            query = query.gte("created_at", value: cutoff)
        case .all, .popular:
            break
        }

        if let goal {
            query = query.contains("goals", value: [goal.rawValue])
        }
        if let difficulty {
            query = query.eq("difficulty", value: difficulty.rawValue)
        }
        if !searchQuery.isEmpty {
            query = query.ilike("title", pattern: "%\(searchQuery)%")
        }

        // Sort
        switch sortBy {
        case .popular:
            query = query.order("import_count", ascending: false)
        case .rating:
            query = query.order("rating", ascending: false)
        case .newest:
            query = query.order("created_at", ascending: false)
        case .price:
            query = query.order("price", ascending: true)
        }

        // Pagination
        let from = page * pageSize
        let to   = from + pageSize - 1
        query = query.range(from: from, to: to)

        let programs: [WorkoutProgram] = try await query.execute().value
        return programs
    }

    /// Fetch a single program by ID (includes exercises)
    func fetchProgram(id: String) async throws -> WorkoutProgram {
        let program: WorkoutProgram = try await supabase
            .from("workout_programs")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return program
    }

    // MARK: - Reviews

    func fetchReviews(programId: String) async throws -> [ProgramReview] {
        let reviews: [ProgramReview] = try await supabase
            .from("program_reviews")
            .select("*")
            .eq("program_id", value: programId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return reviews
    }

    func submitReview(programId: String, rating: Int, body: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceError.notAuthenticated
        }

        struct NewReview: Encodable {
            let program_id: String
            let user_id: String
            let rating: Int
            let body: String
        }

        try await supabase
            .from("program_reviews")
            .insert(NewReview(program_id: programId, user_id: userId, rating: rating, body: body))
            .execute()

        // Refresh average rating in DB (handled by Supabase trigger, see migration)
    }

    // MARK: - Import / Save

    /// Import a program into the current user's library
    func importProgram(_ program: WorkoutProgram) async throws {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceError.notAuthenticated
        }

        struct Import: Encodable {
            let user_id: String
            let program_id: String
            let imported_at: String
        }

        try await supabase
            .from("user_program_imports")
            .upsert(Import(
                user_id: userId,
                program_id: program.id,
                imported_at: ISO8601DateFormatter().string(from: Date())
            ))
            .execute()

        // Increment import count
        try await supabase
            .rpc("increment_import_count", params: ["p_program_id": program.id])
            .execute()
    }

    // MARK: - Create / Publish

    func createProgram(_ program: WorkoutProgram) async throws -> WorkoutProgram {
        let created: WorkoutProgram = try await supabase
            .from("workout_programs")
            .insert(program)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func updateProgram(_ program: WorkoutProgram) async throws {
        try await supabase
            .from("workout_programs")
            .update(program)
            .eq("id", value: program.id)
            .execute()
    }

    func deleteProgram(id: String) async throws {
        try await supabase
            .from("workout_programs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - User Programs

    func fetchMyPrograms() async throws -> [WorkoutProgram] {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceError.notAuthenticated
        }

        let programs: [WorkoutProgram] = try await supabase
            .from("workout_programs")
            .select("*")
            .eq("creator_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return programs
    }

    func fetchImportedPrograms() async throws -> [WorkoutProgram] {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceError.notAuthenticated
        }

        let programs: [WorkoutProgram] = try await supabase
            .from("workout_programs")
            .select("*, user_program_imports!inner(user_id)")
            .eq("user_program_imports.user_id", value: userId)
            .execute()
            .value
        return programs
    }
}

// MARK: - Errors

enum MarketplaceError: LocalizedError {
    case notAuthenticated
    case programNotFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "You must be signed in to perform this action."
        case .programNotFound:   return "Program not found."
        case .networkError(let e): return e.localizedDescription
        }
    }
}
