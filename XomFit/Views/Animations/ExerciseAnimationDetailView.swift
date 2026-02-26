import SwiftUI

/// Complete view for exercise animation with form guide
struct ExerciseAnimationDetailView: View {
    let exerciseId: String
    let exerciseName: String
    
    @Environment(\.dismiss) var dismiss
    @State private var animation: ExerciseAnimationLibrary.AnimationMetadata?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let animation = animation {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Stick Figure Animation
                            StickFigureView(
                                exerciseName: exerciseName,
                                animation: animation
                            )
                            
                            // Form Tips
                            VStack(spacing: 12) {
                                Text("Form Guide")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                FormTipsView(animation: animation)
                                    .padding(.horizontal)
                            }
                            
                            // Exercise Info
                            VStack(spacing: 12) {
                                Text("Exercise Details")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                exerciseInfoCard(animation: animation)
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 20)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.title)
                            .foregroundColor(.red)
                        
                        Text("Animation Not Found")
                            .font(.headline)
                        
                        Text("The animation for this exercise is not available yet.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .onAppear {
                loadAnimation()
            }
        }
    }
    
    // MARK: - Exercise Info Card
    
    @ViewBuilder
    private func exerciseInfoCard(animation: ExerciseAnimationLibrary.AnimationMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Type", value: animation.isCompound ? "Compound" : "Isolation")
                    infoRow(label: "Difficulty", value: animation.difficulty.rawValue)
                    infoRow(label: "Duration", value: String(format: "%.1f sec", animation.duration))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .font(.body)
    }
    
    // MARK: - Private Methods
    
    private func loadAnimation() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animation = ExerciseAnimationLibrary.animationMetadata(for: exerciseId)
            isLoading = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ExerciseAnimationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseAnimationDetailView(
            exerciseId: "ex-1",
            exerciseName: "Bench Press"
        )
    }
}
#endif
