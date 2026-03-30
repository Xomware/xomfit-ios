import Foundation
import WatchConnectivity

/// Watch-side WCSession manager — receives workout context from iPhone, sends logged sets back.
@MainActor
@Observable
class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    var isReachable = false
    var lastReceivedContext: [String: Any] = [:]

    private let session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send

    func sendLoggedSet(_ setData: [String: Any]) {
        let message = ["type": "loggedSet", "payload": setData] as [String: Any]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("WC send error: \(error)")
                // Fall back to transferUserInfo for queued delivery
                self.session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    func sendWorkoutEnded() {
        let message: [String: Any] = ["type": "workoutEnded"]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Encoding Helpers

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
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.handleMessage(userInfo)
        }
    }

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "workoutContext":
            if let payload = message["payload"] as? [String: Any] {
                lastReceivedContext = payload
                WatchWorkoutManager().updateFromPhone(context: payload)
            }
        default:
            break
        }
    }
}
