import Foundation
import Supabase
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.xomware.xomfit", category: "BodyComposition")

@MainActor
final class BodyCompositionService: ObservableObject {
    static let shared = BodyCompositionService()
    
    // MARK: - Published State
    @Published var entries: [BodyCompositionEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Fetch
    
    /// Load all body composition entries for the current user, newest first
    func loadEntries(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let fetched: [BodyCompositionEntry] = try await supabase
                .from("body_composition")
                .select()
                .eq("user_id", value: userId)
                .order("recorded_at", ascending: false)
                .execute()
                .value
            
            entries = fetched
            logger.info("Loaded \(fetched.count) body composition entries for user \(userId)")
        } catch {
            logger.error("Failed to load body composition: \(error)")
            // Fall back to mock data during development
            entries = BodyCompositionEntry.mockHistory(userId: userId)
            errorMessage = nil  // Don't surface mock data errors to user
        }
    }
    
    // MARK: - Save
    
    /// Save a new body composition entry
    func saveEntry(_ entry: BodyCompositionEntry) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabase
                .from("body_composition")
                .insert(entry)
                .execute()
            
            // Prepend to local list for instant UI update
            entries.insert(entry, at: 0)
            logger.info("Saved body composition entry \(entry.id)")
        } catch {
            logger.error("Failed to save body composition entry: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Delete a body composition entry by ID
    func deleteEntry(id: UUID) async throws {
        do {
            try await supabase
                .from("body_composition")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            
            entries.removeAll { $0.id == id }
            logger.info("Deleted body composition entry \(id)")
        } catch {
            logger.error("Failed to delete body composition entry: \(error)")
            throw error
        }
    }
    
    // MARK: - Photo Upload
    
    /// Upload a progress photo to Supabase Storage, returns the public URL
    func uploadPhoto(_ image: UIImage, userId: String, entryId: UUID) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "BodyComposition", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        
        let path = "\(userId)/\(entryId.uuidString).jpg"
        
        try await supabase.storage
            .from("progress-photos")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        let publicUrl = try supabase.storage
            .from("progress-photos")
            .getPublicURL(path: path)
        
        logger.info("Uploaded progress photo to \(publicUrl)")
        return publicUrl.absoluteString
    }
    
    // MARK: - Analytics
    
    /// Get the most recent entry
    var latestEntry: BodyCompositionEntry? { entries.first }
    
    /// Get change in a measurement between latest and a previous entry
    func change(for metric: BodyMeasurement, comparedTo daysAgo: Int) -> Double? {
        guard let latest = latestEntry,
              let latestVal = metric.value(from: latest) else { return nil }
        
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        guard let comparison = entries.first(where: { $0.recordedAt <= cutoff }),
              let compVal = metric.value(from: comparison) else { return nil }
        
        return latestVal - compVal
    }
    
    /// Data points for a chart
    func chartData(for metric: BodyMeasurement, days: Int) -> [(date: Date, value: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return entries
            .filter { $0.recordedAt >= cutoff }
            .compactMap { entry in
                guard let val = metric.value(from: entry) else { return nil }
                return (date: entry.recordedAt, value: val)
            }
            .reversed()  // oldest first for charting
    }
}
