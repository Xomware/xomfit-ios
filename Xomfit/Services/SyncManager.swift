import Foundation
import Network

/// Lightweight offline sync queue. Queues failed operations and retries when connectivity returns.
@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    var pendingCount: Int { pendingOps.count }
    var isSyncing = false

    private var pendingOps: [SyncOperation] = []
    private let monitor = NWPathMonitor()
    private let storageKey = "xomfit_sync_queue"
    private var isConnected = true

    private init() {
        loadQueue()
        startMonitoring()
    }

    // MARK: - Public

    /// Queue a failed operation for retry.
    func enqueue(_ operation: SyncOperation) {
        pendingOps.append(operation)
        saveQueue()
    }

    /// Attempt to sync all pending operations.
    func syncAll() async {
        guard isConnected, !isSyncing, !pendingOps.isEmpty else { return }
        isSyncing = true

        var remaining: [SyncOperation] = []
        for op in pendingOps {
            let success = await execute(op)
            if !success {
                var retried = op
                retried.retryCount += 1
                if retried.retryCount < 5 {
                    remaining.append(retried)
                }
                // Drop after 5 retries
            }
        }

        pendingOps = remaining
        saveQueue()
        isSyncing = false
    }

    // MARK: - Private

    private func execute(_ op: SyncOperation) async -> Bool {
        do {
            switch op.type {
            case .saveWorkout:
                guard let data = op.payload.data(using: .utf8),
                      let workout = try? JSONDecoder().decode(Workout.self, from: data) else { return false }
                try await WorkoutService.shared.saveWorkout(workout)
                return true

            case .postFeedItem:
                // Feed posts are embedded in workout save — skip standalone retry
                return true

            case .likeFeedItem:
                try await FeedService.shared.likeFeedItem(
                    feedItemId: op.entityId,
                    userId: op.userId
                )
                return true

            case .postComment:
                guard let text = op.payload.nilIfEmpty else { return false }
                try await FeedService.shared.postComment(
                    feedItemId: op.entityId,
                    userId: op.userId,
                    text: text
                )
                return true
            }
        } catch {
            return false
        }
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasDisconnected = !(self?.isConnected ?? true)
                self?.isConnected = path.status == .satisfied
                if wasDisconnected && path.status == .satisfied {
                    await self?.syncAll()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "xomfit.sync.monitor"))
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let ops = try? JSONDecoder().decode([SyncOperation].self, from: data) else { return }
        pendingOps = ops
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(pendingOps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Sync Operation

struct SyncOperation: Codable, Identifiable {
    let id: String
    let type: SyncType
    let entityId: String
    let userId: String
    let payload: String
    var retryCount: Int
    let createdAt: Date

    init(type: SyncType, entityId: String, userId: String, payload: String = "") {
        self.id = UUID().uuidString
        self.type = type
        self.entityId = entityId
        self.userId = userId
        self.payload = payload
        self.retryCount = 0
        self.createdAt = Date()
    }

    enum SyncType: String, Codable {
        case saveWorkout
        case postFeedItem
        case likeFeedItem
        case postComment
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
