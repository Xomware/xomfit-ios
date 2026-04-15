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
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var completedSets: Int
        var totalSets: Int
        var currentExercise: String
        var totalExercises: Int
        var isResting: Bool = false
        var restTimeRemaining: Int = 0
        var restEndDate: Date? = nil
    }

    var workoutName: String
    var startTime: Date
}
