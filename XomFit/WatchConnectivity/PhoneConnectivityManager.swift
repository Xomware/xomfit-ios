import Foundation
import WatchConnectivity
import Combine

/// iPhone-side WCSession manager — sends workout context to Watch, receives logged sets.
@MainActor
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable = false
    @Published var isPaired = false
    @Published var receivedSets: [ReceivedWatchSet] = []

    var onSetReceived: ((_ setData: [String: Any]) -> Void)?

    private let session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send to Watch

    func sendWorkoutContext(exercise: String, setNumber: Int, totalSets: Int = 0, restDuration: Int) {
        let payload: [String: Any] = [
            "exercise": exercise,
            "setNumber": setNumber,
            "totalSets": totalSets,
            "restDuration": restDuration
        ]
        let message: [String: Any] = ["type": "workoutContext", "payload": payload]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("Phone WC send error: \(error)")
                self.session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    func sendWorkoutStarted(workoutName: String) {
        let message: [String: Any] = [
            "type": "workoutContext",
            "payload": ["exercise": workoutName, "setNumber": 0, "totalSets": 0, "restDuration": 90]
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}

// MARK: - Received Set Model

struct ReceivedWatchSet: Identifiable {
    let id: String
    let exercise: String
    let weight: Double
    let reps: Int
    let setNumber: Int
    let completedAt: Date
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
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
        case "loggedSet":
            if let payload = message["payload"] as? [String: Any] {
                let set = ReceivedWatchSet(
                    id: payload["id"] as? String ?? UUID().uuidString,
                    exercise: payload["exercise"] as? String ?? "",
                    weight: payload["weight"] as? Double ?? 0,
                    reps: payload["reps"] as? Int ?? 0,
                    setNumber: payload["setNumber"] as? Int ?? 0,
                    completedAt: ISO8601DateFormatter().date(from: payload["completedAt"] as? String ?? "") ?? Date()
                )
                receivedSets.append(set)
                onSetReceived?(payload)
            }
        case "workoutEnded":
            // Could trigger UI update on phone
            break
        default:
            break
        }
    }
}
