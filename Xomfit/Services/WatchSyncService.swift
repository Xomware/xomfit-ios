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
//    WatchSyncService.shared.onDoneSetReceived = { [weak vm] in
//        vm?.completeFocusedSetFromWatch()
//    }
//
//  This file MUST compile against the iOS target alone — it does NOT depend
//  on any watchOS-only API. Receive callbacks are routed through a nonisolated
//  delegate shim to stay compatible with Swift 6 strict concurrency.
//

import Foundation
import Observation
import WatchConnectivity

/// Singleton iOS->watch broadcaster.
///
/// - `sendMessage` is used when the watch is reachable (immediate delivery).
/// - Otherwise falls back to `updateApplicationContext` so the watch can pick
///   up the latest state on cold launch / wake.
@MainActor
@Observable
final class WatchSyncService {
    static let shared = WatchSyncService()

    /// True when a watch is paired AND the companion watch app is installed.
    /// Observable so the iOS UI can render a "watch connected" indicator
    /// (see `WorkoutResumeBar` + `ActiveWorkoutView.headerBar`). Refreshed on
    /// activation and whenever the WCSessionDelegate reports a watch state
    /// change.
    private(set) var isWatchAvailable: Bool = false

    /// Closure invoked when the watch sends `["doneSet": true]`. Wired by the
    /// view model so the watch's "Done Set" button can complete the focused
    /// set on iOS. See `WorkoutLoggerViewModel.completeFocusedSetFromWatch()`
    /// for idempotency guarantees — multiple inbound events within a short
    /// window collapse into a single completion.
    var onDoneSetReceived: (@MainActor () -> Void)?

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
        // `isPaired` / `isWatchAppInstalled` aren't valid until activation
        // completes — the delegate refreshes `isWatchAvailable` for us.
    }

    /// Push a state snapshot to the watch.
    ///
    /// Strategy:
    ///  1. If the session is activated AND the watch is reachable -> `sendMessage`
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

    /// Minimum gap between two accepted `doneSet` events. WCSession will
    /// occasionally deliver the same message twice (once via `sendMessage`
    /// and once via `transferUserInfo` fallback) — without dedup we'd
    /// toggle the set OFF on the second event.
    private static let doneSetDebounceInterval: TimeInterval = 0.75
    private var lastDoneSetAt: Date?

    fileprivate func handle(message: [String: Any]) {
        if let done = message["doneSet"] as? Bool, done {
            let now = Date()
            if let last = lastDoneSetAt,
               now.timeIntervalSince(last) < Self.doneSetDebounceInterval {
                #if DEBUG
                print("[WatchSync] doneSet ignored (debounced)")
                #endif
                return
            }
            lastDoneSetAt = now
            onDoneSetReceived?()
        }
    }

    fileprivate func refreshWatchAvailability() {
        guard WCSession.isSupported() else {
            isWatchAvailable = false
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            isWatchAvailable = false
            return
        }
        isWatchAvailable = session.isPaired && session.isWatchAppInstalled
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
        Task { @MainActor in
            WatchSyncService.shared.refreshWatchAvailability()
        }
    }

    // iOS-only WCSessionDelegate stubs — must be implemented to satisfy the
    // protocol on the iOS side even when we don't use them.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so we can pair with a different watch if the user switches.
        session.activate()
    }

    // iOS-only WCSessionDelegate callbacks for watch-state changes. Each
    // refresh the observable availability flag so the UI indicator stays
    // in sync when the user unpairs or removes the watch app.
    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSyncService.shared.refreshWatchAvailability()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSyncService.shared.refreshWatchAvailability()
        }
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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // `transferUserInfo` is the watch-side fallback when the iPhone isn't
        // reachable. Route it through the same handler so a queued "Done Set"
        // doesn't get dropped.
        Task { @MainActor in
            WatchSyncService.shared.handle(message: userInfo)
        }
    }
}
