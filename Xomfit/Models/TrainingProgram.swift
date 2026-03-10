import Foundation

struct ProgramDay: Identifiable, Codable {
    var id: UUID
    var dayOfWeek: Int // 0 = Sunday, 6 = Saturday
    var templateName: String
    var isRestDay: Bool
    var notes: String
    
    init(id: UUID = UUID(), dayOfWeek: Int, templateName: String = "", isRestDay: Bool = false, notes: String = "") {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.templateName = templateName
        self.isRestDay = isRestDay
        self.notes = notes
    }
    
    var dayName: String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[dayOfWeek]
    }
}

struct ProgramWeek: Identifiable, Codable {
    var id: UUID
    var weekNumber: Int
    var days: [ProgramDay]
    var isDeloadWeek: Bool
    
    init(id: UUID = UUID(), weekNumber: Int, days: [ProgramDay] = [], isDeloadWeek: Bool = false) {
        self.id = id
        self.weekNumber = weekNumber
        self.days = days
        self.isDeloadWeek = isDeloadWeek
    }
}

struct TrainingProgram: Identifiable, Codable {
    var id: UUID
    var name: String
    var description: String
    var durationWeeks: Int
    var daysPerWeek: Int
    var difficulty: ProgramDifficulty
    var goal: ProgramGoal
    var weeks: [ProgramWeek]
    var author: String
    var isPublic: Bool
    var createdAt: Date
    var startDate: Date?
    var isActive: Bool
    
    init(id: UUID = UUID(), name: String, description: String = "", durationWeeks: Int = 4,
         daysPerWeek: Int = 3, difficulty: ProgramDifficulty = .intermediate,
         goal: ProgramGoal = .strength, weeks: [ProgramWeek] = [],
         author: String = "Me", isPublic: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.durationWeeks = durationWeeks
        self.daysPerWeek = daysPerWeek
        self.difficulty = difficulty
        self.goal = goal
        self.weeks = weeks
        self.author = author
        self.isPublic = isPublic
        self.createdAt = Date()
        self.isActive = false
    }
    
    var completedWorkouts: Int { 0 } // Will be tracked separately
    var totalWorkouts: Int { durationWeeks * daysPerWeek }
    var progressPercent: Double { Double(completedWorkouts) / Double(max(totalWorkouts, 1)) }
    
    var currentWeek: Int? {
        guard isActive, let start = startDate else { return nil }
        let days = Int(Date().timeIntervalSince(start) / 86400)
        let week = days / 7 + 1
        return week <= durationWeeks ? week : nil
    }
}

struct ProgramCompletion: Identifiable, Codable {
    var id: UUID
    var programId: UUID
    var weekNumber: Int
    var dayOfWeek: Int
    var completedAt: Date
    
    init(id: UUID = UUID(), programId: UUID, weekNumber: Int, dayOfWeek: Int) {
        self.id = id
        self.programId = programId
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.completedAt = Date()
    }
}
