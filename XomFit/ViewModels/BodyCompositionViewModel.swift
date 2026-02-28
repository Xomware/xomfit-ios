import SwiftUI
import PhotosUI

@MainActor
final class BodyCompositionViewModel: ObservableObject {
    
    // MARK: - Data
    @Published var entries: [BodyCompositionEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddEntry = false
    @Published var showingDeleteConfirm = false
    @Published var entryToDelete: BodyCompositionEntry?
    
    // MARK: - Chart State
    @Published var selectedMetric: BodyMeasurement = .weight
    @Published var selectedTimeRange: TimeRange = .month3
    
    // MARK: - Add Entry Form State
    @Published var formWeight = ""
    @Published var formChest = ""
    @Published var formWaist = ""
    @Published var formHips = ""
    @Published var formBicepLeft = ""
    @Published var formBicepRight = ""
    @Published var formThighLeft = ""
    @Published var formThighRight = ""
    @Published var formCalf = ""
    @Published var formNeck = ""
    @Published var formShoulders = ""
    @Published var formBodyFat = ""
    @Published var formNotes = ""
    @Published var formIsPrivate = true
    @Published var formDate = Date()
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var selectedPhotoImage: UIImage?
    @Published var isSaving = false
    
    private let service = BodyCompositionService.shared
    
    // MARK: - Time Ranges
    enum TimeRange: String, CaseIterable, Identifiable {
        case month1 = "1M"
        case month3 = "3M"
        case month6 = "6M"
        case year1 = "1Y"
        case all = "All"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .month1: return 30
            case .month3: return 90
            case .month6: return 180
            case .year1: return 365
            case .all: return 3650
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var chartData: [(date: Date, value: Double)] {
        service.chartData(for: selectedMetric, days: selectedTimeRange.days)
    }
    
    var latestEntry: BodyCompositionEntry? { service.latestEntry }
    
    var weightChange30d: Double? { service.change(for: .weight, comparedTo: 30) }
    var waistChange30d: Double? { service.change(for: .waist, comparedTo: 30) }
    var bodyFatChange30d: Double? { service.change(for: .bodyFat, comparedTo: 30) }
    
    var isFormValid: Bool {
        // At least one measurement must be filled
        let fields = [formWeight, formChest, formWaist, formHips, formBicepLeft,
                      formBicepRight, formBodyFat, formNotes]
        return fields.contains { !$0.isEmpty }
    }
    
    // MARK: - Load
    
    func load(userId: String) async {
        isLoading = true
        await service.loadEntries(userId: userId)
        entries = service.entries
        isLoading = false
    }
    
    // MARK: - Save Entry
    
    func saveEntry(userId: String) async {
        guard isFormValid else { return }
        isSaving = true
        defer { isSaving = false }
        
        let newId = UUID()
        var photoUrl: String? = nil
        
        // Upload photo if selected
        if let photo = selectedPhotoImage {
            photoUrl = try? await service.uploadPhoto(photo, userId: userId, entryId: newId)
        }
        
        let entry = BodyCompositionEntry(
            id: newId,
            userId: userId,
            recordedAt: formDate,
            weightLbs: Double(formWeight),
            chest: Double(formChest),
            waist: Double(formWaist),
            hips: Double(formHips),
            bicepLeft: Double(formBicepLeft),
            bicepRight: Double(formBicepRight),
            thighLeft: Double(formThighLeft),
            thighRight: Double(formThighRight),
            calf: Double(formCalf),
            neck: Double(formNeck),
            shoulders: Double(formShoulders),
            bodyFatPercent: Double(formBodyFat),
            photoUrl: photoUrl,
            notes: formNotes.isEmpty ? nil : formNotes,
            isPrivate: formIsPrivate
        )
        
        do {
            try await service.saveEntry(entry)
            entries = service.entries
            resetForm()
            showingAddEntry = false
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Entry
    
    func deleteEntry(_ entry: BodyCompositionEntry) async {
        do {
            try await service.deleteEntry(id: entry.id)
            entries = service.entries
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Photo Handler
    
    func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedPhotoImage = image
        }
    }
    
    // MARK: - Helpers
    
    private func resetForm() {
        formWeight = ""; formChest = ""; formWaist = ""; formHips = ""
        formBicepLeft = ""; formBicepRight = ""; formThighLeft = ""; formThighRight = ""
        formCalf = ""; formNeck = ""; formShoulders = ""; formBodyFat = ""
        formNotes = ""; formDate = Date(); formIsPrivate = true
        selectedPhoto = nil; selectedPhotoImage = nil
    }
    
    func formatChange(_ change: Double?, unit: String, lowerIsBetter: Bool = false) -> (text: String, color: Color) {
        guard let change else { return ("—", Theme.textSecondary) }
        let absChange = abs(change)
        let formatted = String(format: "%.1f%@", absChange, unit)
        let isPositive = change > 0
        let isGood = lowerIsBetter ? !isPositive : isPositive
        let sign = isPositive ? "+" : "-"
        return ("\(sign)\(formatted)", isGood ? Theme.accent : Theme.destructive)
    }
}
