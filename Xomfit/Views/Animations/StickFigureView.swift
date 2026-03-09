import SwiftUI

/// Displays animated stick figure demonstrations for exercises
struct StickFigureView: View {
    let exerciseName: String
    let animation: ExerciseAnimationLibrary.AnimationMetadata
    
    @StateObject private var assetManager = AnimationAssetManager.shared
    @State private var animationData: Data?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage: String = ""
    @State private var isPlaying = true
    @State private var loopCount = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label(animation.difficulty.rawValue, systemImage: "figure.strengthtraining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if animation.isCompound {
                            Label("Compound", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Play/Pause button
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Animation Container
            if isLoading {
                ProgressView()
                    .frame(height: 250)
            } else if let _ = animationData {
                // Placeholder for Lottie animation view
                // In real implementation, this would use LottieView from lottie-ios
                VStack(spacing: 0) {
                    // Animation frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 250)
                        
                        VStack {
                            Text("🧍")
                                .font(.system(size: 80))
                            Text("Animation: \(animation.animationFileName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Control buttons
                    HStack(spacing: 12) {
                        Button(action: resetAnimation) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title3)
                        }
                        
                        Spacer()
                        
                        Text("Loop \(loopCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5))
                }
                .padding(.horizontal)
            } else if showError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text("Animation Not Available")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .onAppear {
            loadAnimation()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAnimation() {
        isLoading = true
        assetManager.loadAnimation(named: animation.animationFileName) { data, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data {
                    animationData = data
                    showError = false
                } else {
                    showError = true
                    errorMessage = error?.localizedDescription ?? "Unknown error"
                }
            }
        }
    }
    
    private func resetAnimation() {
        loopCount = 0
        // In real implementation, this would reset the Lottie animation
    }
}

// MARK: - Preview

#if DEBUG
struct StickFigureView_Previews: PreviewProvider {
    static var previews: some View {
        if let benchPress = ExerciseAnimationLibrary.animationMetadata(for: "ex-1") {
            StickFigureView(
                exerciseName: "Bench Press",
                animation: benchPress
            )
            .padding()
        }
    }
}
#endif
