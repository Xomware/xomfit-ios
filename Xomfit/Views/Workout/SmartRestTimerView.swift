import SwiftUI

/// Full-screen modal rest timer with HR-adaptive recovery detection.
struct SmartRestTimerView: View {
    @ObservedObject var viewModel: SmartRestTimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Mode Label
                Text(headerText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.5)
                
                // Countdown Ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 12)
                        .frame(width: 220, height: 220)
                    
                    // Progress
                    Circle()
                        .trim(from: 0, to: viewModel.countdownProgress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.countdownProgress)
                    
                    // Time Display
                    VStack(spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if viewModel.mode == .hrWaiting {
                            Text("Waiting for recovery…")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .scaleEffect(viewModel.isReady ? pulseScale : 1.0)
                .onChange(of: viewModel.isReady) { ready in
                    if ready {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.06
                        }
                    }
                }
                
                // Heart Rate Badge
                if let hr = viewModel.currentHR {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                        Text("\(hr) bpm")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Recovery threshold indicator
                    VStack(spacing: 8) {
                        Text("Ready when < \(viewModel.recoveryThresholdBPM) bpm")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                        
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(recoveryBarColor)
                                    .frame(width: geo.size.width * viewModel.readinessProgress, height: 6)
                                    .animation(.easeInOut(duration: 0.5), value: viewModel.readinessProgress)
                            }
                        }
                        .frame(height: 6)
                        .frame(maxWidth: 200)
                    }
                }
                
                // Ready Banner
                if viewModel.isReady {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Ready! Tap to dismiss")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(14)
                    }
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 16) {
                    timerButton("−30s", systemImage: "minus.circle") {
                        viewModel.addTime(-30)
                    }
                    
                    timerButton("Skip", systemImage: "forward.fill") {
                        viewModel.skip()
                        dismiss()
                    }
                    
                    timerButton("+30s", systemImage: "plus.circle") {
                        viewModel.addTime(30)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Helpers
    
    private var headerText: String {
        switch viewModel.mode {
        case .countdown: return "Rest Timer"
        case .hrWaiting: return "Recovery Monitor"
        }
    }
    
    private var ringColor: Color {
        if viewModel.isReady { return .green }
        if viewModel.mode == .hrWaiting { return .orange }
        return Theme.accent
    }
    
    private var recoveryBarColor: Color {
        viewModel.readinessProgress >= 1.0 ? .green : .orange
    }
    
    private func timerButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(width: 72, height: 56)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    SmartRestTimerView(viewModel: SmartRestTimerViewModel())
}
