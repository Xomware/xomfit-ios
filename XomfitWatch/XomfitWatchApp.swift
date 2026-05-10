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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
                .task {
                    sessionStore.activate()
                }
        }
    }
}
