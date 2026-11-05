import Foundation
import HealthKit

/// What the workout view model needs from the background keep-alive. A seam so
/// tests drive the lifecycle without touching HealthKit.
@MainActor
protocol WorkoutKeepAlive: AnyObject {
    func start()
    func pause()
    func resume()
    func end()
}

/// Runs an iPhone `HKWorkoutSession` (iOS 26+) for the length of a lift.
///
/// The session is here only to keep XomFit running once the phone locks. Without
/// it iOS suspends the app, the 1s session ticker stops, and the Garmin's
/// messages and state pushes die with it (#519).
///
/// Nothing is ever saved to Health. There is no builder, so there is nothing to
/// finish — XomFit does not write strength workouts to Health today, and this
/// must not start doing so as a side effect.
///
/// Without workout share permission the session cannot be created; the workout
/// then runs exactly as before, just without background runtime.
@MainActor
final class PhoneWorkoutSession: NSObject, WorkoutKeepAlive {
    static let shared = PhoneWorkoutSession()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    /// Cleared by `end()`. `start()` awaits the permission sheet, and a workout
    /// discarded while the sheet is up must not get a session afterwards.
    private var wanted = false

    func start() {
        // The app ships at iOS 18; the iPhone workout session arrived in 26.
        // Older phones keep today's behaviour and never see the Health prompt.
        guard #available(iOS 26.0, *) else { return }
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        wanted = true
        Task { await begin() }
    }

    @available(iOS 26.0, *)
    private func begin() async {
        let type = HKObjectType.workoutType()
        // Asks once. HealthKit never shows the sheet again for a type the user
        // has answered, so a denial cannot turn into a prompt on every workout.
        if store.authorizationStatus(for: type) == .notDetermined {
            do {
                try await store.requestAuthorization(toShare: [type], read: [])
            } catch {
                print("[PhoneWorkoutSession] authorization failed: \(error.localizedDescription)")
            }
        }
        guard wanted, session == nil else { return }
        guard store.authorizationStatus(for: type) == .sharingAuthorized else {
            print("[PhoneWorkoutSession] workout sharing not authorized; no background runtime")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            session.delegate = self
            session.startActivity(with: .now)
            self.session = session
        } catch {
            print("[PhoneWorkoutSession] could not start: \(error.localizedDescription)")
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func end() {
        wanted = false
        session?.end()
        session = nil
    }

    /// Drops a session the system ended on its own — another app's workout
    /// taking over, for one — so the next `start()` can make a fresh one.
    private func release(_ ended: ObjectIdentifier) {
        guard let session, ObjectIdentifier(session) == ended else { return }
        self.session = nil
    }
}

extension PhoneWorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in self.release(id) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[PhoneWorkoutSession] session failed: \(error.localizedDescription)")
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in self.release(id) }
    }
}
