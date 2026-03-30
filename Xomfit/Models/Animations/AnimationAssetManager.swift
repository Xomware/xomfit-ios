import Foundation

/// Manages loading and caching of animation assets
@MainActor
@Observable
class AnimationAssetManager {
    static let shared = AnimationAssetManager()

    var cachedAnimations: [String: Data] = [:]
    var loadingAnimations: Set<String> = []
    var failedAnimations: Set<String> = []

    private let fileManager = FileManager.default

    private init() {
        Task {
            await loadCachedAnimations()
        }
    }

    /// Load animation from assets or cache
    func loadAnimation(named fileName: String) async throws -> Data {
        // Check cache first
        if let cached = cachedAnimations[fileName] {
            return cached
        }

        // Mark as loading
        loadingAnimations.insert(fileName)
        defer { loadingAnimations.remove(fileName) }

        // Try to load from bundle
        if let data = loadFromBundle(fileName: fileName) {
            cachedAnimations[fileName] = data
            return data
        }

        // Mark as failed
        failedAnimations.insert(fileName)
        throw AnimationLoadError.fileNotFound(fileName)
    }

    /// Load animation synchronously (for previews)
    func loadAnimationSync(named fileName: String) -> Data? {
        if let cached = cachedAnimations[fileName] {
            return cached
        }
        return loadFromBundle(fileName: fileName)
    }

    /// Preload multiple animations
    func preloadAnimations(_ fileNames: [String]) async {
        for fileName in fileNames {
            _ = try? await loadAnimation(named: fileName)
        }
    }

    /// Clear cache for specific animation
    func clearCache(for fileName: String) {
        cachedAnimations.removeValue(forKey: fileName)
    }

    /// Clear all cache
    func clearAllCache() {
        cachedAnimations.removeAll()
        failedAnimations.removeAll()
    }

    // MARK: - Private

    private func loadFromBundle(fileName: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "") ??
                       Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return nil
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            print("Failed to load animation \(fileName): \(error)")
            return nil
        }
    }

    private func loadCachedAnimations() async {
        let animations = ExerciseAnimationLibrary.allAnimations
        for animation in animations {
            if let data = loadFromBundle(fileName: animation.animationFileName) {
                cachedAnimations[animation.animationFileName] = data
            }
        }
    }
}

enum AnimationLoadError: LocalizedError {
    case fileNotFound(String)
    case invalidManager
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Animation file not found: \(fileName)"
        case .invalidManager:
            return "Animation manager is invalid"
        case .decodingFailed:
            return "Failed to decode animation data"
        }
    }
}
