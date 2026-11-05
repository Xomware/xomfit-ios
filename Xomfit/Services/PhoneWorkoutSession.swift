import Foundation
import HealthKit

/// What the workout view model needs from the background keep-alive. A seam so
/// tests drive the lifecycle without touching HealthKit.
@MainActor
protocol WorkoutKeepAlive: AnyObject {
    /// Picks up a session iOS kept running through a crash. `nil` means there is
    /// no workout it could belong to, so it gets ended.
    func recover(resumableWorkoutStartedAt: Date?)
    func start(workoutStartedAt: Date)
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
///
/// A session outlives a crash: iOS keeps it running and hands it back through
/// `recoverActiveWorkoutSession` on the next launch (#528). It is either adopted
/// by the restored workout or ended, never left running beside a new one.
@MainActor
final class PhoneWorkoutSession: NSObject, WorkoutKeepAlive {
    static let shared = PhoneWorkoutSession()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    /// Cleared by `end()`. `start()` awaits the permission sheet, and a workout
    /// discarded while the sheet is up must not get a session afterwards.
    private var wanted = false
    private var paused = false
    private var workoutStart = Date.distantPast
    /// In flight from launch until iOS answers. `begin()` and `dropRecovered()`
    /// wait on it, so neither acts before the old session is known.
    private var recovery: Task<Void, Never>?
    /// A crash survivor waiting on the restore prompt.
    private var recovered: HKWorkoutSession?

    /// A recovered session belongs to a workout only if it started during it.
    /// One from before was left by an earlier workout and must not be reused.
    nonisolated static func adopts(sessionStartedAt: Date?, workoutStartedAt: Date?) -> Bool {
        guard let sessionStartedAt, let workoutStartedAt else { return false }
        return sessionStartedAt >= workoutStartedAt
    }

    func recover(resumableWorkoutStartedAt: Date?) {
        guard #available(iOS 26.0, *) else { return }
        guard HKHealthStore.isHealthDataAvailable(), recovery == nil else { return }
        recovery = Task { await reclaim(resumableWorkoutStartedAt: resumableWorkoutStartedAt) }
    }

    @available(iOS 26.0, *)
    private func reclaim(resumableWorkoutStartedAt: Date?) async {
        let found: HKWorkoutSession?
        do {
            found = try await store.recoverActiveWorkoutSession()
        } catch {
            print("[PhoneWorkoutSession] recovery failed: \(error.localizedDescription)")
            return
        }
        guard let found else { return }
        found.delegate = self
        guard Self.adopts(sessionStartedAt: found.startDate, workoutStartedAt: resumableWorkoutStartedAt) else {
            found.end()
            return
        }
        recovered = found
    }

    /// Ends the recovered session once the restore is declined.
    func dropRecovered() {
        Task {
            await recovery?.value
            recovered?.end()
            recovered = nil
        }
    }

    func start(workoutStartedAt: Date) {
        // The app ships at iOS 18; the iPhone workout session arrived in 26.
        // Older phones keep today's behaviour and never see the Health prompt.
        guard #available(iOS 26.0, *) else { return }
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        wanted = true
        paused = false
        workoutStart = workoutStartedAt
        Task { await begin() }
    }

    @available(iOS 26.0, *)
    private func begin() async {
        await recovery?.value
        guard wanted, session == nil else { return }
        if let recovered {
            self.recovered = nil
            let live = recovered.state == .running || recovered.state == .paused
            if live, Self.adopts(sessionStartedAt: recovered.startDate, workoutStartedAt: workoutStart) {
                adopt(recovered)
                return
            }
            recovered.end()
        }

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
            if paused { session.pause() }
        } catch {
            print("[PhoneWorkoutSession] could not start: \(error.localizedDescription)")
        }
    }

    @available(iOS 26.0, *)
    private func adopt(_ recovered: HKWorkoutSession) {
        session = recovered
        // A restored workout comes back unpaused, but the lifter may have paused
        // while recovery was in flight. The session follows the workout.
        if paused, recovered.state == .running { recovered.pause() }
        if !paused, recovered.state == .paused { recovered.resume() }
    }

    func pause() {
        paused = true
        session?.pause()
    }

    func resume() {
        paused = false
        session?.resume()
    }

    func end() {
        wanted = false
        session?.end()
        session = nil
        recovered?.end()
        recovered = nil
    }

    /// Drops a session the system ended on its own — another app's workout
    /// taking over, for one — so the next `start()` can make a fresh one.
    private func release(_ ended: ObjectIdentifier) {
        if let recovered, ObjectIdentifier(recovered) == ended { self.recovered = nil }
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
