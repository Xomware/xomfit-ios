//
//  XomfitWidgetAttributes.swift
//  XomfitWidget
//
//  Shared ActivityAttributes for the workout Live Activity.
//  This file is duplicated in Xomfit/Models/ for the main app target.
//  Keep both copies in sync.
//

import ActivityKit

struct XomfitWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var completedSets: Int
        var totalSets: Int
        var currentExercise: String
        var totalExercises: Int
    }

    var workoutName: String
    var startTime: Date
}
