import XCTest
@testable import XomFit

final class WatchConnectivityManagerTests: XCTestCase {

    // MARK: - Message Encoding

    func testEncodeSetMessage_containsCorrectType() {
        let message = WatchConnectivityEncoder.encodeSetMessage(
            exercise: "Bench Press", weight: 225, reps: 5, setNumber: 3
        )
        XCTAssertEqual(message["type"] as? String, "loggedSet")
    }

    func testEncodeSetMessage_payloadContainsAllFields() {
        let message = WatchConnectivityEncoder.encodeSetMessage(
            exercise: "Squat", weight: 315, reps: 3, setNumber: 1
        )
        let payload = message["payload"] as? [String: Any]
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["exercise"] as? String, "Squat")
        XCTAssertEqual(payload?["weight"] as? Double, 315)
        XCTAssertEqual(payload?["reps"] as? Int, 3)
        XCTAssertEqual(payload?["setNumber"] as? Int, 1)
        XCTAssertNotNil(payload?["id"])
        XCTAssertNotNil(payload?["completedAt"])
    }

    // MARK: - Message Decoding

    func testDecodeSetMessage_validPayload() {
        let message: [String: Any] = [
            "type": "loggedSet",
            "payload": [
                "id": "test-id",
                "exercise": "Deadlift",
                "weight": 405.0,
                "reps": 1,
                "setNumber": 5,
                "completedAt": "2026-03-01T12:00:00Z"
            ] as [String: Any]
        ]

        let result = WatchConnectivityEncoder.decodeSetMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.exercise, "Deadlift")
        XCTAssertEqual(result?.weight, 405.0)
        XCTAssertEqual(result?.reps, 1)
        XCTAssertEqual(result?.setNumber, 5)
    }

    func testDecodeSetMessage_missingPayload_returnsNil() {
        let message: [String: Any] = ["type": "loggedSet"]
        let result = WatchConnectivityEncoder.decodeSetMessage(message)
        XCTAssertNil(result)
    }

    func testDecodeSetMessage_incompletePayload_returnsNil() {
        let message: [String: Any] = [
            "type": "loggedSet",
            "payload": ["exercise": "Bench Press"] as [String: Any]
        ]
        let result = WatchConnectivityEncoder.decodeSetMessage(message)
        XCTAssertNil(result)
    }

    // MARK: - Workout Context Encoding

    func testEncodeWorkoutContext() {
        let context = WatchConnectivityEncoder.encodeWorkoutContext(
            exercise: "OHP", setNumber: 2, totalSets: 5, restDuration: 120
        )
        XCTAssertEqual(context["type"] as? String, "workoutContext")
        let payload = context["payload"] as? [String: Any]
        XCTAssertEqual(payload?["exercise"] as? String, "OHP")
        XCTAssertEqual(payload?["restDuration"] as? Int, 120)
    }

    // MARK: - Round Trip

    func testEncodeDecodeRoundTrip() {
        let encoded = WatchConnectivityEncoder.encodeSetMessage(
            exercise: "Lat Pulldown", weight: 150, reps: 12, setNumber: 2
        )
        let decoded = WatchConnectivityEncoder.decodeSetMessage(encoded)
        XCTAssertEqual(decoded?.exercise, "Lat Pulldown")
        XCTAssertEqual(decoded?.weight, 150)
        XCTAssertEqual(decoded?.reps, 12)
        XCTAssertEqual(decoded?.setNumber, 2)
    }
}

// MARK: - Shared Encoder (testable without WCSession)

/// Pure encoding/decoding logic extracted for testability.
enum WatchConnectivityEncoder {
    static func encodeSetMessage(exercise: String, weight: Double, reps: Int, setNumber: Int) -> [String: Any] {
        return [
            "type": "loggedSet",
            "payload": [
                "id": UUID().uuidString,
                "exercise": exercise,
                "weight": weight,
                "reps": reps,
                "setNumber": setNumber,
                "completedAt": ISO8601DateFormatter().string(from: Date())
            ] as [String: Any]
        ]
    }

    static func decodeSetMessage(_ message: [String: Any]) -> (exercise: String, weight: Double, reps: Int, setNumber: Int)? {
        guard let payload = message["payload"] as? [String: Any],
              let exercise = payload["exercise"] as? String,
              let weight = payload["weight"] as? Double,
              let reps = payload["reps"] as? Int,
              let setNumber = payload["setNumber"] as? Int else {
            return nil
        }
        return (exercise, weight, reps, setNumber)
    }

    static func encodeWorkoutContext(exercise: String, setNumber: Int, totalSets: Int, restDuration: Int) -> [String: Any] {
        return [
            "type": "workoutContext",
            "payload": [
                "exercise": exercise,
                "setNumber": setNumber,
                "totalSets": totalSets,
                "restDuration": restDuration
            ] as [String: Any]
        ]
    }
}
