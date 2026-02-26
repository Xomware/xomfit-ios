import SwiftUI

/// Displays form tips, common mistakes, and cues for exercises
struct FormTipsView: View {
    let animation: ExerciseAnimationLibrary.AnimationMetadata
    
    @State private var selectedTab: TipTab = .cues
    
    enum TipTab: String, CaseIterable {
        case cues = "Form Cues"
        case mistakes = "Common Mistakes"
        
        var icon: String {
            switch self {
            case .cues: return "checkmark.circle.fill"
            case .mistakes: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Tips Type", selection: $selectedTab) {
                ForEach(TipTab.allCases, id: \.self) { tab in
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .cues:
                        formCuesContent
                    case .mistakes:
                        commonMistakesContent
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Form Cues Content
    
    var formCuesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                
                Text("Form Cues")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(animation.formCues.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(animation.formCues[index])
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("Follow these cues in order for proper form")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Common Mistakes Content
    
    var commonMistakesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Common Mistakes")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(animation.commonMistakes.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            
                            Text("Mistake \(index + 1)")
                                .font(.subheadline.bold())
                        }
                        
                        Text(animation.commonMistakes[index])
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                
                Text("Avoid these common errors to maximize safety and effectiveness")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FormTipsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if let benchPress = ExerciseAnimationLibrary.animationMetadata(for: "ex-1") {
                FormTipsView(animation: benchPress)
                    .padding()
                    .previewDisplayName("Cues Tab")
            }
            
            if let squat = ExerciseAnimationLibrary.animationMetadata(for: "ex-2") {
                FormTipsView(animation: squat)
                    .padding()
                    .previewDisplayName("Mistakes Tab")
            }
        }
    }
}
#endif
