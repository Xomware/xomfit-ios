//
//  XomfitWidgetAttributes.swift
//  Xomfit
//
//  Shared between main app and widget extension.
//  Add this file to BOTH the Xomfit and XomfitWidgetExtension targets.
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
    }

    var workoutName: String
    var startTime: Date
}
