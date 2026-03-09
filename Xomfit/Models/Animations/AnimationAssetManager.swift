import Foundation

/// Manages loading and caching of animation assets
class AnimationAssetManager: ObservableObject {
    static let shared = AnimationAssetManager()
    
    @Published var cachedAnimations: [String: Data] = [:]
    @Published var loadingAnimations: Set<String> = []
    @Published var failedAnimations: Set<String> = []
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.xomfit.animation-loader", attributes: .concurrent)
    private let lock = NSLock()
    
    private init() {
        loadCachedAnimations()
    }
    
    /// Load animation from assets or cache
    func loadAnimation(named fileName: String, completion: @escaping (Data?, Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil, AnimationLoadError.invalidManager)
                return
            }
            
            // Check cache first
            self.lock.lock()
            if let cached = self.cachedAnimations[fileName] {
                self.lock.unlock()
                completion(cached, nil)
                return
            }
            self.lock.unlock()
            
            // Mark as loading
            DispatchQueue.main.async {
                self.loadingAnimations.insert(fileName)
            }
            
            // Try to load from bundle
            if let data = self.loadFromBundle(fileName: fileName) {
                self.lock.lock()
                self.cachedAnimations[fileName] = data
                self.lock.unlock()
                
                DispatchQueue.main.async {
                    self.loadingAnimations.remove(fileName)
                }
                completion(data, nil)
                return
            }
            
            // Mark as failed
            DispatchQueue.main.async {
                self.loadingAnimations.remove(fileName)
                self.failedAnimations.insert(fileName)
            }
            completion(nil, AnimationLoadError.fileNotFound(fileName))
        }
    }
    
    /// Load animation synchronously (for previews)
    func loadAnimationSync(named fileName: String) -> Data? {
        if let cached = cachedAnimations[fileName] {
            return cached
        }
        return loadFromBundle(fileName: fileName)
    }
    
    /// Preload multiple animations
    func preloadAnimations(_ fileNames: [String]) {
        for fileName in fileNames {
            loadAnimation(named: fileName) { _, _ in
                // Silent preload
            }
        }
    }
    
    /// Clear cache for specific animation
    func clearCache(for fileName: String) {
        lock.lock()
        cachedAnimations.removeValue(forKey: fileName)
        lock.unlock()
    }
    
    /// Clear all cache
    func clearAllCache() {
        lock.lock()
        cachedAnimations.removeAll()
        failedAnimations.removeAll()
        lock.unlock()
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
    
    private func loadCachedAnimations() {
        queue.async { [weak self] in
            let animations = ExerciseAnimationLibrary.allAnimations
            for animation in animations {
                if let data = self?.loadFromBundle(fileName: animation.animationFileName) {
                    self?.lock.lock()
                    self?.cachedAnimations[animation.animationFileName] = data
                    self?.lock.unlock()
                }
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
