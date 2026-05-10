//
//  WatchSyncService.swift
//  Xomfit
//
//  iOS-side WCSession wrapper that broadcasts `WatchWorkoutState` snapshots
//  to a paired Apple Watch app. Mirrors the watch-side `WatchSessionStore`.
//
//  Usage:
//    XomfitApp.task { WatchSyncService.shared.activate() }
//    WorkoutLoggerViewModel.updateLiveActivity() {
//        WatchSyncService.shared.send(state: snapshot)
//    }
//
//  This file MUST compile against the iOS target alone — it does NOT depend
//  on any watchOS-only API. Receive callbacks are routed through a nonisolated
//  delegate shim to stay compatible with Swift 6 strict concurrency.
//

import Foundation
import WatchConnectivity

/// Singleton iOS->watch broadcaster.
///
/// - `sendMessage` is used when the watch is reachable (immediate delivery).
/// - Otherwise falls back to `updateApplicationContext` so the watch can pick
///   up the latest state on cold launch / wake.
@MainActor
final class WatchSyncService {
    static let shared = WatchSyncService()

    private let delegateShim = WatchSyncDelegate()
    private var didActivate = false

    private init() {}

    /// Activate the WCSession. Safe to call multiple times — only the first
    /// call wires the delegate and triggers `session.activate()`.
    func activate() {
        guard !didActivate else { return }
        guard WCSession.isSupported() else { return }
        didActivate = true

        let session = WCSession.default
        session.delegate = delegateShim
        session.activate()
    }

    /// Push a state snapshot to the watch.
    ///
    /// Strategy:
    ///  1. If the session is activated AND the watch is reachable → `sendMessage`
    ///     (low-latency, in-memory only).
    ///  2. Always also stash the latest state in `applicationContext` so the
    ///     watch picks it up on cold launch / re-wake.
    func send(state: WatchWorkoutState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        guard let payload = encode(state) else { return }
        let message: [String: Any] = ["state": payload]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                #if DEBUG
                print("[WatchSync] sendMessage failed: \(error.localizedDescription)")
                #endif
            }
        }

        // Always update the application context so cold-launch is current.
        do {
            try session.updateApplicationContext(message)
        } catch {
            #if DEBUG
            print("[WatchSync] updateApplicationContext failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Inbound (watch -> iOS)

    /// Closure invoked when the watch sends `["doneSet": true]`. Wired by the
    /// view model so the watch's "Done Set" button can complete the focused set.
    var onDoneSetReceived: (@MainActor () -> Void)?

    fileprivate func handle(message: [String: Any]) {
        if let done = message["doneSet"] as? Bool, done {
            onDoneSetReceived?()
        }
    }

    // MARK: - Helpers

    private func encode(_ state: WatchWorkoutState) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(state)
    }
}

/// `WCSessionDelegate` shim — kept off the main actor so its callbacks satisfy
/// the protocol's nonisolated requirements without us sprinkling `nonisolated`
/// on a `@MainActor` class.
private final class WatchSyncDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        #if DEBUG
        if let error {
            print("[WatchSync] activation error: \(error.localizedDescription)")
        } else {
            print("[WatchSync] activation state: \(activationState.rawValue)")
        }
        #endif
    }

    // iOS-only WCSessionDelegate stubs — must be implemented to satisfy the
    // protocol on the iOS side even when we don't use them.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so we can pair with a different watch if the user switches.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            WatchSyncService.shared.handle(message: message)
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            WatchSyncService.shared.handle(message: message)
        }
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            WatchSyncService.shared.handle(message: applicationContext)
        }
    }
}
