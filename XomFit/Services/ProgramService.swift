import Foundation

class ProgramService: ObservableObject {
    static let shared = ProgramService()
    
    @Published var programs: [TrainingProgram] = []
    @Published var activeProgram: TrainingProgram?
    @Published var completions: [ProgramCompletion] = []
    
    private let programsKey = "xomfit_programs"
    private let completionsKey = "xomfit_program_completions"
    
    init() {
        load()
    }
    
    // MARK: - CRUD
    func save(_ program: TrainingProgram) {
        if let idx = programs.firstIndex(where: { $0.id == program.id }) {
            programs[idx] = program
        } else {
            programs.append(program)
        }
        if program.isActive { activeProgram = program }
        persist()
    }
    
    func delete(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        if activeProgram?.id == program.id { activeProgram = nil }
        persist()
    }
    
    func duplicate(_ program: TrainingProgram) -> TrainingProgram {
        var copy = program
        copy.id = UUID()
        copy.name = "\(program.name) (Copy)"
        copy.isActive = false
        copy.startDate = nil
        programs.append(copy)
        persist()
        return copy
    }
    
    // MARK: - Activation
    func activate(_ program: TrainingProgram) {
        // Deactivate current
        if let idx = programs.firstIndex(where: { $0.isActive }) {
            programs[idx].isActive = false
        }
        // Activate new
        if let idx = programs.firstIndex(where: { $0.id == program.id }) {
            programs[idx].isActive = true
            programs[idx].startDate = Date()
            activeProgram = programs[idx]
        }
        persist()
    }
    
    // MARK: - Completion Tracking
    func markCompleted(programId: UUID, week: Int, day: Int) {
        let completion = ProgramCompletion(programId: programId, weekNumber: week, dayOfWeek: day)
        completions.append(completion)
        persistCompletions()
    }
    
    func completionsForProgram(_ programId: UUID) -> [ProgramCompletion] {
        completions.filter { $0.programId == programId }
    }
    
    func progressForProgram(_ programId: UUID, totalDays: Int) -> Double {
        let count = completionsForProgram(programId).count
        return Double(count) / Double(max(totalDays, 1))
    }
    
    // MARK: - Community Programs
    func communityPrograms() -> [TrainingProgram] {
        [
            makeProgram("StrongLifts 5x5", desc: "Classic barbell strength program. 3 days/week, 12 weeks.", weeks: 12, days: 3, difficulty: .beginner, goal: .strength, author: "Mehdi"),
            makeProgram("PHUL Powerbuilding", desc: "Power/Hypertrophy Upper/Lower split. 4 days/week.", weeks: 8, days: 4, difficulty: .intermediate, goal: .hypertrophy, author: "Brandon Lilly"),
            makeProgram("GZCLP Linear", desc: "GZCLP — tiered progression. 3 days/week.", weeks: 16, days: 3, difficulty: .beginner, goal: .strength, author: "Cody Lefever"),
            makeProgram("PPL 6-Day Push Pull Legs", desc: "Push Pull Legs split. 6 days/week for advanced lifters.", weeks: 12, days: 6, difficulty: .advanced, goal: .hypertrophy, author: "Jeff Nippard"),
            makeProgram("531 Boring But Big", desc: "Jim Wendler's 5/3/1 with BBB accessories.", weeks: 16, days: 4, difficulty: .intermediate, goal: .strength, author: "Jim Wendler"),
            makeProgram("Beginner Full Body", desc: "Simple 3-day full body for complete beginners.", weeks: 8, days: 3, difficulty: .beginner, goal: .generalFitness, author: "XomFit")
        ]
    }
    
    // MARK: - Program Builder Helper
    func buildDefaultWeeks(for program: TrainingProgram) -> [ProgramWeek] {
        (1...program.durationWeeks).map { weekNum in
            let isDeload = weekNum % 4 == 0
            let days = buildDefaultDays(daysPerWeek: program.daysPerWeek)
            return ProgramWeek(weekNumber: weekNum, days: days, isDeloadWeek: isDeload)
        }
    }
    
    func buildDefaultDays(daysPerWeek: Int) -> [ProgramDay] {
        // Distribute workout days evenly (Mon/Wed/Fri for 3 days, etc.)
        let schedules: [Int: [Int]] = [
            1: [1],
            2: [1, 4],
            3: [1, 3, 5],
            4: [1, 2, 4, 5],
            5: [1, 2, 3, 4, 5],
            6: [1, 2, 3, 4, 5, 6]
        ]
        let workoutDays = schedules[daysPerWeek] ?? [1, 3, 5]
        return (0...6).map { day in
            ProgramDay(dayOfWeek: day,
                      templateName: workoutDays.contains(day) ? "Workout \(workoutDays.firstIndex(of: day).map { $0 + 1 } ?? 1)" : "",
                      isRestDay: !workoutDays.contains(day))
        }
    }
    
    // MARK: - Persistence
    private func persist() {
        if let data = try? JSONEncoder().encode(programs) {
            UserDefaults.standard.set(data, forKey: programsKey)
        }
    }
    
    private func persistCompletions() {
        if let data = try? JSONEncoder().encode(completions) {
            UserDefaults.standard.set(data, forKey: completionsKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: programsKey),
           let decoded = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            programs = decoded
            activeProgram = programs.first { $0.isActive }
        }
        if let data = UserDefaults.standard.data(forKey: completionsKey),
           let decoded = try? JSONDecoder().decode([ProgramCompletion].self, from: data) {
            completions = decoded
        }
    }
    
    private func makeProgram(_ name: String, desc: String, weeks: Int, days: Int,
                              difficulty: ProgramDifficulty, goal: ProgramGoal, author: String) -> TrainingProgram {
        TrainingProgram(name: name, description: desc, durationWeeks: weeks, daysPerWeek: days,
                       difficulty: difficulty, goal: goal, author: author, isPublic: true)
    }
}
