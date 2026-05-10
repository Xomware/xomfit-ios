//
//  WatchSessionStore.swift
//  XomfitWatch
//
//  Watch-side WCSession receiver. Decodes `WatchWorkoutState` snapshots from
//  the paired iPhone and exposes them as observable state for `ContentView`.
//  Sends `["doneSet": true]` back to iOS when the user taps "Done Set".
//
//  Mirror of iOS-side `WatchSyncService` — kept on the watch target so it
//  doesn't pull in any iOS-only frameworks.
//

import Foundation
import Observation
import WatchConnectivity

/// Receiver-mode store for the watch app. Activates WCSession, decodes
/// inbound state, and pushes outbound "done set" messages back to iOS.
@Observable
@MainActor
final class WatchSessionStore {
    /// Latest decoded snapshot from the iPhone. `nil` until first message
    /// arrives — UI should render an "Open the iPhone app to start a workout"
    /// placeholder while this is `nil`.
    var state: WatchWorkoutState?

    /// True after `WCSession.activate()` succeeds. Used to disable the
    /// "Done Set" button while we're not yet able to reply.
    var isActivated = false

    private let delegateShim = WatchSessionDelegate()
    private var didActivate = false

    init() {
        delegateShim.store = self
    }

    /// Activate the WCSession. Safe to call multiple times.
    func activate() {
        guard !didActivate else { return }
        guard WCSession.isSupported() else { return }
        didActivate = true

        let session = WCSession.default
        session.delegate = delegateShim
        session.activate()
    }

    /// Tell the iPhone to mark the focused set as complete. No-op if the
    /// phone isn't currently reachable AND we have no fallback channel.
    func sendDoneSet() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let message: [String: Any] = ["doneSet": true]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                #if DEBUG
                print("[WatchSession] sendMessage failed: \(error.localizedDescription)")
                #endif
            }
        } else {
            // Best-effort fallback for queued delivery if the phone isn't
            // currently reachable (locked, app suspended, etc.).
            session.transferUserInfo(message)
        }
    }

    // MARK: - Inbound

    fileprivate func handle(message: [String: Any]) {
        guard let payload = message["state"] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(WatchWorkoutState.self, from: payload) else {
            #if DEBUG
            print("[WatchSession] failed to decode WatchWorkoutState")
            #endif
            return
        }
        state = decoded
    }

    fileprivate func setActivated(_ activated: Bool) {
        isActivated = activated
    }
}

/// `WCSessionDelegate` shim — kept off the main actor so its callbacks satisfy
/// the protocol's nonisolated requirements without us sprinkling `nonisolated`
/// on a `@MainActor` class.
private final class WatchSessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    weak var store: WatchSessionStore?

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        let activated = (activationState == .activated && error == nil)
        Task { @MainActor [weak store] in
            store?.setActivated(activated)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak store] in
            store?.handle(message: message)
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor [weak store] in
            store?.handle(message: message)
        }
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak store] in
            store?.handle(message: applicationContext)
        }
    }
}
