import SwiftUI

struct SmartRestTimerSettingsView: View {
    @AppStorage("smartRestTimer_enabled") private var enabled = true
    @AppStorage("smartRestTimer_maxHR") private var maxHR = 190
    @AppStorage("smartRestTimer_threshold") private var threshold = 0.65
    
    var body: some View {
        Form {
            Section {
                Toggle("Smart Rest Timer", isOn: $enabled)
            } footer: {
                Text("When enabled, the rest timer monitors your heart rate and signals when you've recovered enough for the next set.")
            }
            
            if enabled {
                Section("Heart Rate") {
                    Stepper("Max Heart Rate: \(maxHR) bpm", value: $maxHR, in: 140...220)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recovery Threshold: \(Int(threshold * 100))%")
                        Slider(value: $threshold, in: 0.50...0.80, step: 0.05)
                        Text("Ready when HR drops below \(Int(Double(maxHR) * threshold)) bpm")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Section("Default Rest Durations") {
                    Label("Compound (squat, bench): 3:00", systemImage: "figure.strengthtraining.traditional")
                    Label("Isolation (curls): 1:30", systemImage: "figure.curling")
                    Label("Cardio (circuits): 1:00", systemImage: "figure.run")
                }
            }
        }
        .navigationTitle("Smart Rest Timer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SmartRestTimerSettingsView()
    }
}
