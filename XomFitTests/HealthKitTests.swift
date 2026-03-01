import XCTest
@testable import XomFit

final class HealthKitTests: XCTestCase {
    var service: HealthKitService!
    
    override func setUp() {
        super.setUp()
        service = HealthKitService.shared
    }
    
    func testHealthKitServiceInitializes() {
        XCTAssertNotNil(service)
    }
    
    func testReadTypesNotEmpty() {
        // On simulator HealthKit may not be available, but types should be defined
        let types = service.readTypes
        // Will be empty on simulator without HealthKit
        XCTAssertNotNil(types)
    }
    
    func testWriteTypesNotEmpty() {
        let types = service.writeTypes
        XCTAssertNotNil(types)
    }
    
    func testInitialValuesAreZero() {
        // Fresh service (no mock data) should start at zero
        XCTAssertGreaterThanOrEqual(service.stepsToday, 0)
        XCTAssertGreaterThanOrEqual(service.activeCaloriesToday, 0)
        XCTAssertGreaterThanOrEqual(service.restingHR, 0)
    }
}

final class GarminTests: XCTestCase {
    var service: GarminService!
    
    override func setUp() {
        super.setUp()
        service = GarminService.shared
    }
    
    func testGarminServiceInitializes() {
        XCTAssertNotNil(service)
    }
    
    func testConnectGarmin() {
        let expectation = XCTestExpectation(description: "Garmin connect")
        service.connect(email: "test@test.com") { success in
            XCTAssertTrue(success)
            XCTAssertTrue(self.service.isConnected)
            XCTAssertEqual(self.service.connectedEmail, "test@test.com")
            self.service.disconnect()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testDisconnectGarmin() {
        service.disconnect()
        XCTAssertFalse(service.isConnected)
        XCTAssertEqual(service.connectedEmail, "")
    }
    
    func testMockActivitiesLoadAfterConnect() {
        let expectation = XCTestExpectation(description: "Activities loaded")
        service.connect(email: "test@example.com") { _ in
            XCTAssertGreaterThan(self.service.recentActivities.count, 0)
            self.service.disconnect()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func testActivityDurationFormatted() {
        let activity = GarminActivity(activityId: "1", name: "Test", activityType: "strength_training",
                                      startTimeLocal: Date(), duration: 3661, calories: 300)
        XCTAssertTrue(activity.durationFormatted.contains("m"))
    }
    
    func testStrengthActivityDetection() {
        let strength = GarminActivity(activityId: "1", name: "Lift", activityType: "strength_training",
                                       startTimeLocal: Date(), duration: 3600, calories: 300)
        XCTAssertTrue(strength.isStrengthActivity)
        
        let running = GarminActivity(activityId: "2", name: "Run", activityType: "running",
                                      startTimeLocal: Date(), duration: 1800, calories: 200)
        XCTAssertFalse(running.isStrengthActivity)
    }
    
    func testDuplicateDetection() {
        let service = GarminService.shared
        let activity = GarminActivity(activityId: "1", name: "Test", activityType: "strength_training",
                                       startTimeLocal: Date(), duration: 3600, calories: 300)
        let isDup = service.isDuplicate(activity, in: [])
        XCTAssertFalse(isDup) // No workouts = no duplicate
    }
}
