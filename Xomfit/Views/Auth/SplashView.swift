import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo with animation
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.accent)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("XomFit")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .opacity(opacity)
                    
                    Text("Train Together. Get Stronger.")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Loading indicator
                ProgressView()
                    .tint(Theme.accent)
                    .opacity(opacity)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
