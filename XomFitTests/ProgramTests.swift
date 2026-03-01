import XCTest
@testable import XomFit

final class ProgramTests: XCTestCase {
    var service: ProgramService!
    
    override func setUp() {
        super.setUp()
        service = ProgramService.shared
    }
    
    func testCreateProgram() {
        let program = TrainingProgram(name: "Test Program", durationWeeks: 4, daysPerWeek: 3)
        XCTAssertEqual(program.name, "Test Program")
        XCTAssertEqual(program.durationWeeks, 4)
        XCTAssertEqual(program.daysPerWeek, 3)
        XCTAssertFalse(program.isActive)
    }
    
    func testTotalWorkoutsCalculation() {
        let program = TrainingProgram(name: "Test", durationWeeks: 8, daysPerWeek: 4)
        XCTAssertEqual(program.totalWorkouts, 32)
    }
    
    func testProgressPercentDefault() {
        let program = TrainingProgram(name: "Test", durationWeeks: 4, daysPerWeek: 3)
        XCTAssertEqual(program.progressPercent, 0.0, accuracy: 0.01)
    }
    
    func testBuildDefaultWeeks() {
        let program = TrainingProgram(name: "Test", durationWeeks: 4, daysPerWeek: 3)
        let weeks = service.buildDefaultWeeks(for: program)
        XCTAssertEqual(weeks.count, 4)
    }
    
    func testDeloadWeekOnWeek4() {
        let program = TrainingProgram(name: "Test", durationWeeks: 4, daysPerWeek: 3)
        let weeks = service.buildDefaultWeeks(for: program)
        XCTAssertTrue(weeks[3].isDeloadWeek)
    }
    
    func testBuildDefaultDaysFor3Days() {
        let days = service.buildDefaultDays(daysPerWeek: 3)
        XCTAssertEqual(days.count, 7)
        let workoutDays = days.filter { !$0.isRestDay }
        XCTAssertEqual(workoutDays.count, 3)
    }
    
    func testCommunityProgramsCount() {
        let programs = service.communityPrograms()
        XCTAssertGreaterThanOrEqual(programs.count, 5)
    }
    
    func testProgramDuplicate() {
        let original = TrainingProgram(name: "Original")
        service.save(original)
        let copy = service.duplicate(original)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertTrue(copy.name.contains("Copy"))
        service.delete(original)
        service.delete(copy)
    }
    
    func testProgramActivation() {
        let program = TrainingProgram(name: "Activate Test")
        service.save(program)
        service.activate(program)
        XCTAssertTrue(service.programs.first(where: { $0.id == program.id })?.isActive ?? false)
        service.delete(program)
    }
    
    func testProgramDayNames() {
        let day = ProgramDay(dayOfWeek: 1, templateName: "Upper Body")
        XCTAssertEqual(day.dayName, "Mon")
    }
}
