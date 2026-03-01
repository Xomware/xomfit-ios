import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.xomware.xomfit", category: "ProgressPhotos")

/// Metadata for a progress photo stored locally
struct ProgressPhoto: Identifiable, Codable {
    let id: UUID
    let date: Date
    let bodyCompositionEntryId: UUID?
    let weightKg: Double?
    let notes: String?
    
    var filename: String { "\(id.uuidString).jpg" }
}

/// Manages progress photos stored as JPEG in the app's Documents directory
@MainActor
final class ProgressPhotoService: ObservableObject {
    static let shared = ProgressPhotoService()
    
    @Published var photos: [ProgressPhoto] = []
    
    private let metadataKey = "progress_photos_metadata"
    private let photoDirName = "ProgressPhotos"
    
    private var photoDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(photoDirName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() {
        loadMetadata()
    }
    
    // MARK: - CRUD
    
    func addPhoto(image: UIImage, date: Date, entryId: UUID? = nil, weightKg: Double? = nil, notes: String? = nil) -> ProgressPhoto? {
        let photo = ProgressPhoto(id: UUID(), date: date, bodyCompositionEntryId: entryId, weightKg: weightKg, notes: notes)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to encode image as JPEG")
            return nil
        }
        
        let fileURL = photoDirectory.appendingPathComponent(photo.filename)
        do {
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to write photo: \(error)")
            return nil
        }
        
        photos.append(photo)
        photos.sort { $0.date > $1.date }
        saveMetadata()
        logger.info("Saved progress photo \(photo.id)")
        return photo
    }
    
    func deletePhoto(_ photo: ProgressPhoto) {
        let fileURL = photoDirectory.appendingPathComponent(photo.filename)
        try? FileManager.default.removeItem(at: fileURL)
        photos.removeAll { $0.id == photo.id }
        saveMetadata()
    }
    
    func loadImage(for photo: ProgressPhoto) -> UIImage? {
        let fileURL = photoDirectory.appendingPathComponent(photo.filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Persistence
    
    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let decoded = try? JSONDecoder().decode([ProgressPhoto].self, from: data) else { return }
        photos = decoded.sorted { $0.date > $1.date }
    }
    
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }
}
