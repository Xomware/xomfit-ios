//
//  WatchWorkoutState.swift
//  XomfitWatch
//
//  Snapshot the iOS app pushes to the Apple Watch via WCSession.
//
//  This file is duplicated in `Xomfit/Models/WatchWorkoutState.swift` for the
//  iOS target (same pattern as `XomfitWidgetAttributes.swift`).
//  KEEP BOTH COPIES IN SYNC — fields, types, and Codable shape must match
//  exactly or the watch will silently drop messages.
//

import Foundation

/// Lightweight state snapshot the iOS app broadcasts to the watch on every
/// Live Activity tick (rest start/end, set complete, pause toggle, etc.).
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
