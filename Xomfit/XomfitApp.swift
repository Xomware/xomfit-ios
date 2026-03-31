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
                            Image("XomFitBanner")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                            XomFitLoaderPaint(size: 60)
                        }
                    }
                } else if authService.isAuthenticated {
                    MainTabView()
                        .environment(authService)
                        .sheet(isPresented: Bindable(authService).needsProfileCompletion) {
                            ProfileCompletionView()
                                .environment(authService)
                                .interactiveDismissDisabled()
                        }
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
