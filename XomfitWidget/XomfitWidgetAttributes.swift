//
//  XomfitWidgetAttributes.swift
//  XomfitWidget
//
//  Shared ActivityAttributes for the workout Live Activity.
//  This file is duplicated in Xomfit/Models/ for the main app target.
//  Keep both copies in sync.
//

import ActivityKit
import Foundation

struct XomfitWidgetAttributes: ActivityAttributes {
    /// Which Live Activity flow this payload drives. Older payloads omit
    /// `mode` and decode as `.workout` so the existing workout Live Activity
    /// keeps rendering unchanged (#398).
    public enum Mode: String, Codable, Hashable {
        case workout
        case stretch
    }

    public struct ContentState: Codable, Hashable {
        // MARK: - Workout fields
        var elapsedSeconds: Int
        var completedSets: Int
        var totalSets: Int
        var currentExercise: String
        var totalExercises: Int
        var isResting: Bool = false
        var restTimeRemaining: Int = 0
        var restEndDate: Date? = nil
        var isOvertime: Bool = false
        var isPaused: Bool = false

        // MARK: - Stretch sequence fields (#398)
        /// Which Live Activity flow this is. Defaults to `.workout` so old
        /// payloads decode cleanly.
        var mode: Mode = .workout
        /// Name of the stretch currently being held. Only meaningful when
        /// `mode == .stretch`.
        var stretchName: String = ""
        /// Seconds remaining on the current stretch. Allowed to go negative
        /// once the user holds past the recommended time.
        var stretchSecondsRemaining: Int = 0
        /// 1-based index of the current stretch in the sequence.
        var stretchIndex: Int = 0
        /// Total stretches in the sequence.
        var stretchTotal: Int = 0
    }

    var workoutName: String
    var startTime: Date
}
