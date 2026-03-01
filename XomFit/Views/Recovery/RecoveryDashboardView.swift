import SwiftUI

struct RecoveryDashboardView: View {
    @StateObject private var viewModel = RecoveryViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overtraining alert
                    if viewModel.isOvertrainingRisk {
                        overtrainingAlert
                    }
                    
                    // Readiness gauge
                    if let readiness = viewModel.readiness {
                        ReadinessGaugeCard(readiness: readiness)
                    }
                    
                    // Sleep logger
                    sleepSection
                    
                    // Soreness map
                    sorenessSection
                    
                    // Recovery timeline
                    recoveryTimelineSection
                }
                .padding()
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Sleep") { viewModel.showSleepLogger = true }
                        Button("HRV") { viewModel.showHRVLogger = true }
                    }
                }
            }
            .onAppear { viewModel.loadAll() }
            .sheet(isPresented: $viewModel.showSleepLogger) {
                SleepLoggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showHRVLogger) {
                HRVLoggerSheet(viewModel: viewModel)
            }
        }
    }
    
    private var overtrainingAlert: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Overtraining risk detected. Consider taking 1-2 rest days.")
                .font(.subheadline)
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep")
                    .font(.headline)
                Spacer()
                Button("Log Sleep") { viewModel.showSleepLogger = true }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
            
            if let lastSleep = viewModel.sleepLog.first {
                HStack {
                    Label("\(String(format: "%.1f", lastSleep.hoursSlept))h", systemImage: "moon.fill")
                    Spacer()
                    Label("Quality: \(lastSleep.quality)/5", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("Score: \(lastSleep.recoveryScore)")
                        .font(.caption)
                        .bold()
                }
                .font(.subheadline)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("No sleep logged yet. Tap 'Log Sleep' to track recovery.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private var sorenessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Soreness")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.soreness) { muscle in
                    SorenessCard(muscle: muscle) { level in
                        viewModel.updateSoreness(muscle: muscle.muscleGroup, level: level)
                    }
                }
            }
        }
    }
    
    private var recoveryTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Timeline")
                .font(.headline)
            
            ForEach(viewModel.recoveryTimeline, id: \.0) { (muscle, date, isReady) in
                HStack {
                    Circle()
                        .fill(isReady ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(muscle)
                        .font(.subheadline)
                    Spacer()
                    if isReady {
                        Text("Ready ✓")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Ready \(date, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Readiness Gauge Card
struct ReadinessGaugeCard: View {
    let readiness: DailyReadiness
    
    var gaugeColor: Color {
        switch readiness.score {
        case 75...: return .green
        case 60..<75: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Readiness")
                        .font(.headline)
                    Text(readiness.status.emoji + " " + readiness.status.rawValue)
                        .font(.subheadline)
                        .foregroundColor(gaugeColor)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness.score) / 100)
                        .stroke(gaugeColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Text("\(readiness.score)")
                        .font(.title2)
                        .bold()
                }
            }
            
            // Component breakdown
            HStack(spacing: 16) {
                ReadinessComponent(label: "Sleep", value: readiness.sleepScore)
                ReadinessComponent(label: "Soreness", value: readiness.sorenessScore)
                ReadinessComponent(label: "Load", value: readiness.trainingLoadScore)
                ReadinessComponent(label: "HRV", value: readiness.hrvScore)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ReadinessComponent: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundColor(value >= 60 ? .primary : .orange)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Soreness Card
struct SorenessCard: View {
    let muscle: MuscleSoreness
    let onUpdate: (SorenessLevel) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(muscle.muscleGroup)
                    .font(.caption)
                    .bold()
                Spacer()
                Text(muscle.level.label)
                    .font(.caption2)
                    .foregroundColor(sorenessColor(muscle.level))
            }
            HStack(spacing: 4) {
                ForEach(SorenessLevel.allCases, id: \.rawValue) { level in
                    Circle()
                        .fill(muscle.level.rawValue >= level.rawValue ? sorenessColor(level) : Color.gray.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .onTapGesture { onUpdate(level) }
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    func sorenessColor(_ level: SorenessLevel) -> Color {
        switch level {
        case .none: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .significant: return .red
        case .severe: return .purple
        }
    }
}

// MARK: - Sleep Logger Sheet
struct SleepLoggerSheet: View {
    @ObservedObject var viewModel: RecoveryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Hours Slept") {
                    HStack {
                        Text(String(format: "%.1f hours", viewModel.sleepHours))
                            .font(.title2)
                            .bold()
                        Spacer()
                    }
                    Slider(value: $viewModel.sleepHours, in: 3...12, step: 0.5)
                }
                Section("Sleep Quality") {
                    Picker("Quality", selection: $viewModel.sleepQuality) {
                        ForEach(1...5, id: \.self) { q in
                            Text(String(repeating: "⭐", count: q)).tag(q)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { viewModel.logSleep() } }
            }
        }
    }
}

// MARK: - HRV Logger Sheet
struct HRVLoggerSheet: View {
    @ObservedObject var viewModel: RecoveryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("HRV (ms)") {
                    TextField("e.g. 65", text: $viewModel.hrvValue)
                        .keyboardType(.decimalPad)
                }
                Section("Resting HR (bpm)") {
                    TextField("e.g. 55", text: $viewModel.restingHR)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Log HRV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { viewModel.logHRV() } }
            }
        }
    }
}
