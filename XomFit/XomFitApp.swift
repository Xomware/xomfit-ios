import SwiftUI

@main
struct XomFitApp: App {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var showSessionErrorAlert = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if sessionManager.shouldShowSplash && !sessionManager.authService.isInitialized {
                    SplashView()
                } else if !sessionManager.authService.isAuthenticated {
                    LoginView()
                        .environmentObject(sessionManager.authService)
                        .preferredColorScheme(.dark)
                } else {
                    MainTabView()
                        .environmentObject(sessionManager.authService)
                        .preferredColorScheme(.dark)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                // Session validation is handled by SessionManager
            }
            .onOpenURL { url in
                Task {
                    await sessionManager.authService.handleOAuthRedirect(url)
                }
            }
            .onChange(of: sessionManager.sessionError) { oldValue, newValue in
                if newValue != nil {
                    showSessionErrorAlert = true
                }
            }
            .alert("Session Expired", isPresented: $showSessionErrorAlert) {
                Button("OK", role: .default) {
                    sessionManager.clearSessionError()
                }
            } message: {
                if let error = sessionManager.sessionError {
                    Text(error)
                }
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }
                .tag(0)
            
            WorkoutView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Workout")
                }
                .tag(1)
            
            XomProgressView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .tint(Theme.accent)
    }
}
