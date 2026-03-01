import SwiftUI
import WatchConnectivity

@main
struct XomFitWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WorkoutControlView()
                .environmentObject(connectivityManager)
                .environmentObject(workoutManager)
        }
    }
}
