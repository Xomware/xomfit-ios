import XCTest
@testable import XomFit

final class BodyCompositionTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testBodyCompositionEntryCodable() throws {
        let entry = BodyCompositionEntry(
            userId: "test-user",
            recordedAt: Date(),
            weightLbs: 185.0,
            chest: 42.0,
            waist: 33.0,
            bodyFatPercent: 18.0,
            isPrivate: true
        )
        
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(BodyCompositionEntry.self, from: data)
        
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.weightLbs, 185.0)
        XCTAssertEqual(decoded.chest, 42.0)
        XCTAssertEqual(decoded.waist, 33.0)
        XCTAssertEqual(decoded.bodyFatPercent, 18.0)
        XCTAssertEqual(decoded.isPrivate, true)
    }
    
    func testBodyCompositionEntryIdentifiable() {
        let entry = BodyCompositionEntry(userId: "test")
        XCTAssertNotNil(entry.id)
    }
    
    func testBodyCompositionEntryOptionalFields() {
        let entry = BodyCompositionEntry(userId: "test")
        XCTAssertNil(entry.weightLbs)
        XCTAssertNil(entry.bodyFatPercent)
        XCTAssertNil(entry.chest)
        XCTAssertNil(entry.notes)
        XCTAssertNil(entry.photoUrl)
    }
    
    // MARK: - BodyMeasurement Tests
    
    func testBodyMeasurementValueExtraction() {
        let entry = BodyCompositionEntry(
            userId: "test",
            weightLbs: 185.0,
            chest: 42.0,
            waist: 33.0,
            bodyFatPercent: 18.0,
            isPrivate: true
        )
        
        XCTAssertEqual(BodyMeasurement.weight.value(from: entry), 185.0)
        XCTAssertEqual(BodyMeasurement.chest.value(from: entry), 42.0)
        XCTAssertEqual(BodyMeasurement.waist.value(from: entry), 33.0)
        XCTAssertEqual(BodyMeasurement.bodyFat.value(from: entry), 18.0)
        XCTAssertNil(BodyMeasurement.calf.value(from: entry))
    }
    
    func testBodyMeasurementUnits() {
        XCTAssertEqual(BodyMeasurement.weight.unit, "lbs")
        XCTAssertEqual(BodyMeasurement.bodyFat.unit, "%")
        XCTAssertEqual(BodyMeasurement.chest.unit, "in")
        XCTAssertEqual(BodyMeasurement.waist.unit, "in")
    }
    
    func testBodyMeasurementAllCases() {
        XCTAssertEqual(BodyMeasurement.allCases.count, 12)
    }
    
    // MARK: - Mock Data Tests
    
    func testMockHistoryGeneration() {
        let history = BodyCompositionEntry.mockHistory(userId: "test")
        XCTAssertEqual(history.count, 12)
        
        // Should be sorted oldest first
        for i in 0..<history.count - 1 {
            XCTAssertLessThan(history[i].recordedAt, history[i + 1].recordedAt)
        }
    }
    
    func testMockHistoryHasWeights() {
        let history = BodyCompositionEntry.mockHistory(userId: "test")
        for entry in history {
            XCTAssertNotNil(entry.weightLbs)
        }
    }
    
    // MARK: - ProgressPhoto Tests
    
    func testProgressPhotoCodable() throws {
        let photo = ProgressPhoto(
            id: UUID(),
            date: Date(),
            bodyCompositionEntryId: UUID(),
            weightKg: 84.0,
            notes: "Morning photo"
        )
        
        let data = try JSONEncoder().encode(photo)
        let decoded = try JSONDecoder().decode(ProgressPhoto.self, from: data)
        
        XCTAssertEqual(decoded.id, photo.id)
        XCTAssertEqual(decoded.weightKg, 84.0)
        XCTAssertEqual(decoded.notes, "Morning photo")
    }
    
    func testProgressPhotoFilename() {
        let id = UUID()
        let photo = ProgressPhoto(id: id, date: Date(), bodyCompositionEntryId: nil, weightKg: nil, notes: nil)
        XCTAssertEqual(photo.filename, "\(id.uuidString).jpg")
    }
    
    // MARK: - ViewModel Tests
    
    @MainActor
    func testViewModelFormValidation() {
        let vm = BodyCompositionViewModel()
        
        // Empty form should be invalid
        XCTAssertFalse(vm.isFormValid)
        
        // Adding weight should make it valid
        vm.formWeight = "185"
        XCTAssertTrue(vm.isFormValid)
    }
    
    @MainActor
    func testViewModelFormatChangePositive() {
        let vm = BodyCompositionViewModel()
        let (text, _) = vm.formatChange(2.5, unit: " lbs", lowerIsBetter: false)
        XCTAssertEqual(text, "+2.5 lbs")
    }
    
    @MainActor
    func testViewModelFormatChangeNegative() {
        let vm = BodyCompositionViewModel()
        let (text, _) = vm.formatChange(-1.5, unit: "%", lowerIsBetter: true)
        XCTAssertEqual(text, "-1.5%")
    }
    
    @MainActor
    func testViewModelFormatChangeNil() {
        let vm = BodyCompositionViewModel()
        let (text, _) = vm.formatChange(nil, unit: " lbs")
        XCTAssertEqual(text, "—")
    }
    
    @MainActor
    func testViewModelTimeRanges() {
        XCTAssertEqual(BodyCompositionViewModel.TimeRange.allCases.count, 5)
        XCTAssertEqual(BodyCompositionViewModel.TimeRange.month1.days, 30)
        XCTAssertEqual(BodyCompositionViewModel.TimeRange.year1.days, 365)
    }
}
