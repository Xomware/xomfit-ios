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

    // MARK: - Wearable detail
    //
    // Added for the watch's extra screens. Every field is optional-with-default
    // so a watch running an older build still decodes a newer phone's payload —
    // Codable treats a missing key as a hard failure otherwise, and the two
    // sides update independently through separate stores.

    /// Planned reps and weight for the current set.
    var reps: Int? = nil
    var weight: Double? = nil
    /// Names of the exercises still to come, nearest first.
    var upNext: [String] = []
    /// One form cue for the current lift.
    var instruction: String? = nil
    /// Whether the wrist should buzz through the end of rest. Decided on the
    /// phone so the setting lives in one place, and sent rather than asked for
    /// because the watch cannot read iPhone defaults.
    var wristHaptics: Bool = true

    // MARK: - Decoding
    //
    // Written by hand because Swift's synthesized decoder ignores property
    // defaults: a merely *absent* key is a hard failure, not a fallback.
    //
    // That matters more here than anywhere else in the app. The phone and the
    // watch ship through different stores and update independently, so their
    // builds routinely disagree — an older watch will see fields it has never
    // heard of, and a newer watch will see a payload missing the ones it wants.
    // Without this, either direction means every message is silently dropped
    // and the watch just sits there looking broken.
    //
    // Add a field with a default, add it here too.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workoutName = try c.decode(String.self, forKey: .workoutName)
        currentExercise = try c.decode(String.self, forKey: .currentExercise)
        setNumber = try c.decode(Int.self, forKey: .setNumber)
        totalSets = try c.decode(Int.self, forKey: .totalSets)
        isResting = try c.decode(Bool.self, forKey: .isResting)
        restEndDate = try c.decodeIfPresent(Date.self, forKey: .restEndDate)
        isPaused = try c.decode(Bool.self, forKey: .isPaused)
        elapsedSeconds = try c.decode(Int.self, forKey: .elapsedSeconds)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        upNext = try c.decodeIfPresent([String].self, forKey: .upNext) ?? []
        instruction = try c.decodeIfPresent(String.self, forKey: .instruction)
        // Defaults to buzzing rather than silence: a dropped flag should not
        // quietly disable the one feature the watch exists for.
        wristHaptics = try c.decodeIfPresent(Bool.self, forKey: .wristHaptics) ?? true
    }

    /// Memberwise init, spelled out because the hand-written `init(from:)`
    /// suppresses the synthesized one.
    init(
        workoutName: String,
        currentExercise: String,
        setNumber: Int,
        totalSets: Int,
        isResting: Bool,
        restEndDate: Date? = nil,
        isPaused: Bool,
        elapsedSeconds: Int,
        reps: Int? = nil,
        weight: Double? = nil,
        upNext: [String] = [],
        instruction: String? = nil,
        wristHaptics: Bool = true
    ) {
        self.workoutName = workoutName
        self.currentExercise = currentExercise
        self.setNumber = setNumber
        self.totalSets = totalSets
        self.isResting = isResting
        self.restEndDate = restEndDate
        self.isPaused = isPaused
        self.elapsedSeconds = elapsedSeconds
        self.reps = reps
        self.weight = weight
        self.upNext = upNext
        self.instruction = instruction
        self.wristHaptics = wristHaptics
    }
}

