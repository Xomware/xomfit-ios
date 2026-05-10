//
//  WatchWorkoutState.swift
//  Xomfit
//
//  Snapshot the iOS app pushes to the Apple Watch via WCSession.
//
//  This file is duplicated in `XomfitWatch/WatchWorkoutState.swift` for the
//  watchOS target (same pattern as `XomfitWidgetAttributes.swift`).
//  KEEP BOTH COPIES IN SYNC — fields, types, and Codable shape must match
//  exactly or the watch will silently drop messages.
//

import Foundation

/// Lightweight state snapshot the iOS app broadcasts to the watch on every
/// Live Activity tick (rest start/end, set complete, pause toggle, etc.).
///
/// Encoded as JSON inside the WCSession message payload under the key `state`.
struct WatchWorkoutState: Codable, Hashable {
    var workoutName: String
    var currentExercise: String
    var setNumber: Int
    var totalSets: Int
    var isResting: Bool
    var restEndDate: Date?
    var isPaused: Bool
    var elapsedSeconds: Int
}
