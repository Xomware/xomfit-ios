import XCTest
@testable import XomFit

final class ExportTests: XCTestCase {
    var service: ExportService!
    
    override func setUp() {
        super.setUp()
        service = ExportService.shared
    }
    
    func testCSVExportHasHeader() {
        let csv = service.exportWorkoutsCSV()
        XCTAssertTrue(csv.hasPrefix("Date,Time,Exercise,Set #,Reps,Weight (lbs),Volume (lbs),Notes"))
    }
    
    func testCSVExportIsString() {
        let csv = service.exportWorkoutsCSV()
        XCTAssertFalse(csv.isEmpty)
    }
    
    func testJSONExportIsValidData() {
        let json = service.exportWorkoutsJSON()
        XCTAssertNotNil(json)
        if let data = json {
            let parsed = try? JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(parsed)
        }
    }
    
    func testPDFReportContainsHeader() {
        let data = service.exportPDFReport()
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("XomFit Training Log"))
    }
    
    func testWorkoutSummaryReturnsData() {
        let summary = service.workoutSummary()
        XCTAssertGreaterThanOrEqual(summary.totalWorkouts, 0)
        XCTAssertGreaterThanOrEqual(summary.totalVolumeLbs, 0)
    }
    
    func testCSVExportWithDateRange() {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let end = Date()
        let csv = service.exportWorkoutsCSV(from: start, to: end)
        XCTAssertTrue(csv.hasPrefix("Date,"))
    }
    
    func testTopExerciseReturnsString() {
        let top = service.topExercise()
        XCTAssertNotNil(top)
    }
}
