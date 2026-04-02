//
//  XomfitWidgetControl.swift
//  XomfitWidget
//
//  Control Center widget for quick workout start.
//

import AppIntents
import SwiftUI
import WidgetKit

struct XomfitWidgetControl: ControlWidget {
    static let kind: String = "com.Xomware.Xomfit.XomfitWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenWorkoutIntent()) {
                Label("Start Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("Start Workout")
        .description("Quickly start a new workout in XomFit.")
    }
}

struct OpenWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Opens the app — deep link handling can route to workout
        return .result()
    }
}
