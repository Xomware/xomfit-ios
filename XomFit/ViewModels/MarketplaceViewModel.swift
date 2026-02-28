import Foundation
import Combine

@MainActor
class MarketplaceViewModel: ObservableObject {

    // MARK: - Published State

    @Published var programs: [WorkoutProgram] = []
    @Published var featuredPrograms: [WorkoutProgram] = []
    @Published var myPrograms: [WorkoutProgram] = []
    @Published var importedPrograms: [WorkoutProgram] = []

    @Published var selectedFilter: MarketplaceFilter = .all
    @Published var selectedGoal: ProgramGoal? = nil
    @Published var selectedDifficulty: ProgramDifficulty? = nil
    @Published var sortOrder: MarketplaceSortOrder = .popular
    @Published var searchQuery: String = ""

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var importedProgramIds: Set<String> = []

    // MARK: - Pagination

    private var currentPage = 0
    private var hasMorePages = true
    private let pageSize = 20

    // MARK: - Dependencies

    private let service = MarketplaceService.shared
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Debounced search
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        $selectedFilter.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        $selectedGoal.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        $selectedDifficulty.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        $sortOrder.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
    }

    // MARK: - Load

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 0
        hasMorePages = true

        do {
            async let all = service.fetchPrograms(
                filter: selectedFilter,
                goal: selectedGoal,
                difficulty: selectedDifficulty,
                sortBy: sortOrder,
                searchQuery: searchQuery,
                page: 0,
                pageSize: pageSize
            )
            async let featured = service.fetchPrograms(filter: .featured, sortBy: .rating, page: 0, pageSize: 6)

            let (loadedPrograms, loadedFeatured) = try await (all, featured)
            programs = loadedPrograms
            featuredPrograms = loadedFeatured
            hasMorePages = loadedPrograms.count == pageSize
            currentPage = 1
        } catch {
            // Fallback to mock data for development
            programs = WorkoutProgram.mockPrograms
            featuredPrograms = WorkoutProgram.mockPrograms.filter { $0.isFeatured }
            errorMessage = nil // Silently use mock
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true

        do {
            let more = try await service.fetchPrograms(
                filter: selectedFilter,
                goal: selectedGoal,
                difficulty: selectedDifficulty,
                sortBy: sortOrder,
                searchQuery: searchQuery,
                page: currentPage,
                pageSize: pageSize
            )
            programs.append(contentsOf: more)
            hasMorePages = more.count == pageSize
            currentPage += 1
        } catch {
            // Silently fail on pagination
        }

        isLoadingMore = false
    }

    func loadMyContent() async {
        do {
            async let mine     = service.fetchMyPrograms()
            async let imported = service.fetchImportedPrograms()
            let (myList, importedList) = try await (mine, imported)
            myPrograms = myList
            importedPrograms = importedList
            importedProgramIds = Set(importedList.map { $0.id })
        } catch {
            myPrograms = []
            importedPrograms = []
        }
    }

    func refresh() {
        Task { await loadInitial() }
    }

    // MARK: - Import

    func importProgram(_ program: WorkoutProgram) async -> Bool {
        do {
            try await service.importProgram(program)
            importedProgramIds.insert(program.id)
            // Optimistically bump import count
            if let idx = programs.firstIndex(where: { $0.id == program.id }) {
                programs[idx] = WorkoutProgram(
                    id: program.id,
                    title: program.title,
                    description: program.description,
                    creatorId: program.creatorId,
                    creatorName: program.creatorName,
                    creatorAvatarUrl: program.creatorAvatarUrl,
                    daysPerWeek: program.daysPerWeek,
                    durationWeeks: program.durationWeeks,
                    difficulty: program.difficulty,
                    goals: program.goals,
                    exercises: program.exercises,
                    price: program.price,
                    rating: program.rating,
                    reviewCount: program.reviewCount,
                    importCount: program.importCount + 1,
                    isFeatured: program.isFeatured,
                    isPublic: program.isPublic,
                    tags: program.tags,
                    createdAt: program.createdAt,
                    updatedAt: Date()
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func isImported(_ program: WorkoutProgram) -> Bool {
        importedProgramIds.contains(program.id)
    }

    // MARK: - Create / Publish

    func publishProgram(_ program: WorkoutProgram) async -> Bool {
        do {
            let created = try await service.createProgram(program)
            myPrograms.insert(created, at: 0)
            if created.isPublic {
                programs.insert(created, at: 0)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteMyProgram(_ program: WorkoutProgram) async {
        do {
            try await service.deleteProgram(id: program.id)
            myPrograms.removeAll { $0.id == program.id }
            programs.removeAll { $0.id == program.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filters

    var activeFilterCount: Int {
        var count = 0
        if selectedFilter != .all    { count += 1 }
        if selectedGoal != nil       { count += 1 }
        if selectedDifficulty != nil { count += 1 }
        return count
    }

    func clearFilters() {
        selectedFilter     = .all
        selectedGoal       = nil
        selectedDifficulty = nil
        sortOrder          = .popular
    }

    // MARK: - Grouped by goal (for browse grid)

    var programsByGoal: [(ProgramGoal, [WorkoutProgram])] {
        var dict: [ProgramGoal: [WorkoutProgram]] = [:]
        for prog in programs {
            for goal in prog.goals {
                dict[goal, default: []].append(prog)
            }
        }
        return ProgramGoal.allCases.compactMap { goal in
            guard let list = dict[goal], !list.isEmpty else { return nil }
            return (goal, Array(list.prefix(6)))
        }
    }
}
