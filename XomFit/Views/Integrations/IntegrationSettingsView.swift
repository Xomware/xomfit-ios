import SwiftUI

struct IntegrationSettingsView: View {
    @StateObject private var viewModel = IntegrationViewModel()
    @State private var showGarminConnect = false
    
    var body: some View {
        NavigationView {
            List {
                // Apple Health
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.subheadline)
                                .bold()
                            Text(viewModel.healthKitAuthorized ? "Connected" : "Not connected")
                                .font(.caption)
                                .foregroundColor(viewModel.healthKitAuthorized ? .green : .secondary)
                        }
                        Spacer()
                        if viewModel.healthKitAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Connect") { viewModel.connectHealthKit() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    
                    if viewModel.healthKitAuthorized {
                        HealthDataRow(icon: "figure.walk", label: "Steps Today", value: "\(viewModel.stepsToday)")
                        HealthDataRow(icon: "heart.fill", label: "Resting HR", value: viewModel.restingHR > 0 ? "\(Int(viewModel.restingHR)) bpm" : "—")
                        HealthDataRow(icon: "flame.fill", label: "Active Calories", value: "\(viewModel.activeCalories) kcal")
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("XomFit reads steps, sleep, HR, HRV and writes workouts and active calories to Apple Health.")
                }
                
                // Garmin
                Section {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(.blue)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Garmin Connect")
                                .font(.subheadline)
                                .bold()
                            Text(viewModel.garminConnected ? "Connected as \(viewModel.garminEmail)" : "Not connected")
                                .font(.caption)
                                .foregroundColor(viewModel.garminConnected ? .green : .secondary)
                        }
                        Spacer()
                        if viewModel.garminConnected {
                            Button("Disconnect") { viewModel.disconnectGarmin() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        } else {
                            Button("Connect") { showGarminConnect = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    
                    if viewModel.garminConnected {
                        if let summary = viewModel.garminSummary {
                            HealthDataRow(icon: "figure.walk", label: "Steps Today", value: "\(summary.steps)")
                            HealthDataRow(icon: "battery.100", label: "Body Battery", value: "\(summary.bodyBattery)/100")
                            HealthDataRow(icon: "waveform.path.ecg", label: "Stress", value: "\(summary.averageStress)/100")
                            if let vo2 = summary.vo2Max {
                                HealthDataRow(icon: "lungs.fill", label: "VO2 Max", value: String(format: "%.1f", vo2))
                            }
                        }
                        
                        Button(action: { viewModel.syncGarmin() }) {
                            HStack {
                                if viewModel.isSyncing {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(viewModel.isSyncing ? "Syncing..." : "Sync Now")
                            }
                        }
                        .disabled(viewModel.isSyncing)
                    }
                } header: {
                    Text("Garmin")
                } footer: {
                    Text("Import activities from Garmin Connect. Duplicate detection prevents double-counting workouts.")
                }
                
                // Recent Garmin Activities
                if viewModel.garminConnected && !viewModel.garminActivities.isEmpty {
                    Section("Recent Garmin Activities") {
                        ForEach(viewModel.garminActivities.prefix(5)) { activity in
                            GarminActivityRow(activity: activity) {
                                viewModel.importGarminActivity(activity)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Integrations")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadAll() }
            .sheet(isPresented: $showGarminConnect) {
                GarminConnectSheet(viewModel: viewModel, isPresented: $showGarminConnect)
            }
        }
    }
}

struct HealthDataRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct GarminActivityRow: View {
    let activity: GarminActivity
    let onImport: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline)
                    .bold()
                HStack {
                    Text(activity.durationFormatted)
                    Text("·")
                    Text("\(activity.calories) kcal")
                    if let hr = activity.averageHR {
                        Text("·")
                        Text("\(hr) bpm avg")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Text(activity.startTimeLocal, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if activity.xomfitMapped {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Import") { onImport() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GarminConnectSheet: View {
    @ObservedObject var viewModel: IntegrationViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Garmin Connect Account") {
                    TextField("Email address", text: $viewModel.garminEmailInput)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                Section {
                    Text("XomFit will import your recent activities, daily steps, body battery, and sleep data from Garmin Connect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Connect Garmin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isConnecting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("Connect") {
                            viewModel.connectGarmin()
                            isPresented = false
                        }
                        .disabled(viewModel.garminEmailInput.isEmpty)
                    }
                }
            }
        }
    }
}
