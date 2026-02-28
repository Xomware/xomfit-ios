import SwiftUI

struct AICoachSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: AICoachViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                Form {
                    // Training Split
                    Section(header: Text("Training Program")) {
                        Picker("Preferred Split", selection: $viewModel.userPreferences.preferredSplit) {
                            ForEach([
                                ProgramRecommendation.SplitType.fullBody,
                                .upperLower,
                                .pushPullLegs,
                                .bodypartSplit,
                                .custom
                            ], id: \.self) { split in
                                Text(split.displayName).tag(split)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Frequency
                    Section(header: Text("Training Frequency")) {
                        Stepper(
                            "Days Per Week: \(viewModel.userPreferences.targetDaysPerWeek)",
                            value: $viewModel.userPreferences.targetDaysPerWeek,
                            in: 1...7
                        )
                    }
                    
                    // Rep Range
                    Section(header: Text("Preferred Rep Range")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Minimum Reps")
                                Spacer()
                                Text("\(viewModel.userPreferences.repRangePreference.min)")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Double(viewModel.userPreferences.repRangePreference.min),
                                in: 1...20,
                                step: 1
                            ) { _ in
                                // Update handler
                            }
                            onEditingChanged: { _ in
                                if viewModel.userPreferences.repRangePreference.min >= viewModel.userPreferences.repRangePreference.max {
                                    viewModel.userPreferences.repRangePreference.max = viewModel.userPreferences.repRangePreference.min + 1
                                }
                            }
                            
                            HStack {
                                Text("Maximum Reps")
                                Spacer()
                                Text("\(viewModel.userPreferences.repRangePreference.max)")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Double(viewModel.userPreferences.repRangePreference.max),
                                in: 1...30,
                                step: 1
                            ) { _ in
                                // Update handler
                            }
                            onEditingChanged: { _ in
                                if viewModel.userPreferences.repRangePreference.max <= viewModel.userPreferences.repRangePreference.min {
                                    viewModel.userPreferences.repRangePreference.min = viewModel.userPreferences.repRangePreference.max - 1
                                }
                            }
                        }
                    }
                    
                    // Rest Period
                    Section(header: Text("Rest Period Between Sets")) {
                        Picker("Rest Seconds", selection: $viewModel.userPreferences.restPeriodSeconds) {
                            ForEach([45, 60, 75, 90, 120, 150, 180], id: \.self) { seconds in
                                Text("\(seconds)s").tag(seconds)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Deload Settings
                    Section(header: Text("Recovery & Deload")) {
                        Toggle("Auto Deload Suggestions", isOn: $viewModel.userPreferences.enableAutoDeload)
                        
                        if viewModel.userPreferences.enableAutoDeload {
                            Stepper(
                                "Deload Every \(viewModel.userPreferences.deloadFrequencyWeeks) Weeks",
                                value: $viewModel.userPreferences.deloadFrequencyWeeks,
                                in: 4...12
                            )
                        }
                    }
                    
                    // Equipment Preferences
                    Section(header: Text("Equipment Preferences")) {
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Toggle(equipment.displayName, isOn: Binding(
                                get: { viewModel.userPreferences.preferredEquipment.contains(equipment) },
                                set: { isSelected in
                                    if isSelected {
                                        viewModel.userPreferences.preferredEquipment.append(equipment)
                                    } else {
                                        viewModel.userPreferences.preferredEquipment.removeAll { $0 == equipment }
                                    }
                                }
                            ))
                        }
                    }
                    
                    // Info Section
                    Section(header: Text("About AI Coach")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🤖 Powered by machine learning")
                                .font(.system(.caption, design: .default))
                            Text("Learns from your workout history to provide personalized recommendations")
                                .font(.system(.caption, design: .default))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("AI Coach Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

#Preview {
    AICoachSettingsView(viewModel: AICoachViewModel())
}
