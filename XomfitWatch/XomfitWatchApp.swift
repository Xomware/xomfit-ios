//
//  XomfitWatchApp.swift
//  XomfitWatch
//
//  watchOS app entry point. Single WindowGroup -> ContentView.
//  Owns the singleton WatchSessionStore so it survives view rebuilds.
//

import SwiftUI

@main
struct XomfitWatchApp: App {
    @State private var sessionStore = WatchSessionStore()

    /// Owns the `HKWorkoutSession`.
    ///
    /// This existed and was compiled but never constructed, so nothing ever
    /// called `start()`. Without a running workout session watchOS suspends the
    /// app on wrist-down and the elapsed timer stops advancing — which is the
    /// entire reason the file exists. It lives here rather than in a view so it
    /// survives view rebuilds, same as the session store.
    @State private var workoutSession = WatchWorkoutSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
                .environment(workoutSession)
                .task {
                    sessionStore.activate()
                    // Ask once at launch. Declining only costs heart rate and
                    // calories; the mirrored timer and Done Set still work.
                    await workoutSession.requestAuthorization()
                }
                // Track the phone: a session on the watch is only meaningful
                // while the iPhone has a workout in progress. Starting on our
                // own would open a workout the lifter never began.
                .onChange(of: sessionStore.state == nil) { _, noWorkout in
                    if noWorkout {
                        workoutSession.stop()
                    } else if !workoutSession.isRunning {
                        workoutSession.start()
                    }
                }
        }
    }
}
