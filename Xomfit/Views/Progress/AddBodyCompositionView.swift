import SwiftUI
import PhotosUI

struct AddBodyCompositionView: View {
    @ObservedObject var viewModel: BodyCompositionViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Date
                        dateSection
                        
                        // Photo
                        photoSection
                        
                        // Weight & Body Fat
                        primarySection
                        
                        // Circumference Measurements
                        measurementsSection
                        
                        // Notes & Privacy
                        notesSection
                        
                        // Save Button
                        Button {
                            Task {
                                guard let userId = authService.currentUser?.id else { return }
                                await viewModel.saveEntry(userId: userId)
                            }
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            } else {
                                Text("Log Check-in")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                        }
                        .foregroundStyle(.black)
                        .background(viewModel.isFormValid && !viewModel.isSaving ? Theme.accent : Theme.accent.opacity(0.3))
                        .cornerRadius(Theme.cornerRadius)
                        .disabled(!viewModel.isFormValid || viewModel.isSaving)
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.bottom, Theme.paddingLarge)
                    }
                    .padding(.top, Theme.paddingMedium)
                }
            }
            .navigationTitle("New Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .onChange(of: viewModel.selectedPhoto) { _, newItem in
                Task { await viewModel.handlePhotoSelection(newItem) }
            }
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyCompSectionHeader("Date")
            DatePicker(
                "Check-in Date",
                selection: $viewModel.formDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .tint(Theme.accent)
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyCompSectionHeader("Progress Photo")
            
            PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                HStack(spacing: 12) {
                    if let image = viewModel.selectedPhotoImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .fill(Theme.secondaryBackground)
                                .frame(width: 80, height: 80)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedPhotoImage != nil ? "Photo selected" : "Add a progress photo")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Optional · Private by default")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.paddingMedium)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
    
    // MARK: - Primary Section (Weight + Body Fat)
    
    private var primarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyCompSectionHeader("Weight & Body Fat")
            
            VStack(spacing: 1) {
                MeasurementField(
                    label: "Weight",
                    placeholder: "185.0",
                    unit: "lbs",
                    text: $viewModel.formWeight
                )
                
                Divider()
                    .background(Theme.background)
                    .padding(.horizontal, Theme.paddingMedium)
                
                MeasurementField(
                    label: "Body Fat",
                    placeholder: "18.0",
                    unit: "%",
                    text: $viewModel.formBodyFat
                )
            }
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
    
    // MARK: - Measurements Section
    
    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyCompSectionHeader("Circumference Measurements (inches)")
            
            VStack(spacing: 1) {
                let measurements: [(String, Binding<String>)] = [
                    ("Chest", $viewModel.formChest),
                    ("Waist", $viewModel.formWaist),
                    ("Hips", $viewModel.formHips),
                    ("Left Bicep", $viewModel.formBicepLeft),
                    ("Right Bicep", $viewModel.formBicepRight),
                    ("Left Thigh", $viewModel.formThighLeft),
                    ("Right Thigh", $viewModel.formThighRight),
                    ("Calf", $viewModel.formCalf),
                    ("Neck", $viewModel.formNeck),
                    ("Shoulders", $viewModel.formShoulders),
                ]
                
                ForEach(Array(measurements.enumerated()), id: \.offset) { idx, item in
                    MeasurementField(
                        label: item.0,
                        placeholder: "—",
                        unit: "in",
                        text: item.1
                    )
                    if idx < measurements.count - 1 {
                        Divider()
                            .background(Theme.background)
                            .padding(.horizontal, Theme.paddingMedium)
                    }
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
    
    // MARK: - Notes & Privacy
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyCompSectionHeader("Notes & Privacy")
            
            VStack(spacing: 1) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Optional notes (e.g. morning weight, after workout...)", text: $viewModel.formNotes, axis: .vertical)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3, reservesSpace: true)
                        .padding(Theme.paddingMedium)
                }
                
                Divider()
                    .background(Theme.background)
                
                Toggle(isOn: $viewModel.formIsPrivate) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.formIsPrivate ? "lock.fill" : "globe")
                            .foregroundStyle(viewModel.formIsPrivate ? Theme.accent : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.formIsPrivate ? "Private" : "Public")
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textPrimary)
                            Text(viewModel.formIsPrivate ? "Only visible to you" : "Visible to your followers")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .tint(Theme.accent)
                .padding(Theme.paddingMedium)
            }
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }
}

// MARK: - Helper Views

private struct BodyCompSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

private struct MeasurementField: View {
    let label: String
    let placeholder: String
    let unit: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 120, alignment: .leading)
            
            Spacer()
            
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 80)
            
            Text(unit)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, alignment: .leading)
        }
        .padding(Theme.paddingMedium)
    }
}
