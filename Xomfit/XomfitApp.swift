import SwiftUI

@main
struct XomFitApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        VStack(spacing: Theme.paddingMedium) {
                            Text("XOMFIT")
                                .font(.system(size: 42, weight: .black))
                                .foregroundColor(Theme.accent)
                                .tracking(4)
                            ProgressView()
                                .tint(Theme.accent)
                        }
                    }
                } else if authService.isAuthenticated {
                    MainTabView()
                        .environment(authService)
                } else {
                    LoginView()
                        .environment(authService)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                Task {
                    try? await supabase.auth.session(from: url)
                }
            }
        }
    }
}
