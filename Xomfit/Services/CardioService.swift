import Foundation
import Supabase

// MARK: - Rows

private struct CardioRow: Codable {
    let id: String
    let userId: String
    let modality: String
    let startTime: String
    let endTime: String
    let durationSeconds: Double
    let distanceMiles: Double?
    let activeCalories: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let elevationGainFeet: Double?
    let notes: String?
    let healthkitUUID: String?
    let sourceName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case modality
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case distanceMiles = "distance_miles"
        case activeCalories = "active_calories"
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case elevationGainFeet = "elevation_gain_feet"
        case notes
        case healthkitUUID = "healthkit_uuid"
        case sourceName = "source_name"
    }
}

private struct CardioUpsertPayload: Encodable {
    let id: String
    let user_id: String
    let modality: String
    let start_time: String
    let end_time: String
    let duration_seconds: Double
    let distance_miles: Double?
    let active_calories: Double?
    let average_heart_rate: Double?
    let max_heart_rate: Double?
    let elevation_gain_feet: Double?
    let notes: String?
    let healthkit_uuid: String?
    let source_name: String?
}

// MARK: - Service

@MainActor
@Observable
final class CardioService {
    static let shared = CardioService()

    private(set) var sessions: [CardioSession] = []
    private(set) var lastError: String?

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Fetch

    @discardableResult
    func fetchSessions(userId: String, limit: Int = 100) async -> [CardioSession] {
        do {
            let rows: [CardioRow] = try await supabase
                .from("cardio_sessions")
                .select()
                .eq("user_id", value: userId)
                .order("start_time", ascending: false)
                .limit(limit)
                .execute()
                .value

            sessions = rows.compactMap(session(from:))
            lastError = nil
            return sessions
        } catch {
            lastError = error.localizedDescription
            print("[CardioService] fetch failed: \(error)")
            return sessions
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ session: CardioSession) async -> Bool {
        do {
            try await supabase
                .from("cardio_sessions")
                .upsert(payload(from: session))
                .execute()

            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.insert(session, at: 0)
                sessions.sort { $0.startTime > $1.startTime }
            }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            print("[CardioService] save failed: \(error)")
            return false
        }
    }

    func delete(id: String) async {
        do {
            try await supabase
                .from("cardio_sessions")
                .delete()
                .eq("id", value: id)
                .execute()
            sessions.removeAll { $0.id == id }
        } catch {
            lastError = error.localizedDescription
            print("[CardioService] delete failed: \(error)")
        }
    }

    // MARK: - Health import

    /// Pulls cardio from Apple Health and saves anything new.
    ///
    /// Returns the number of sessions actually imported. Duplicates are rejected
    /// by the unique index on (user_id, healthkit_uuid) rather than by a
    /// read-then-check here, so two devices importing at the same time cannot
    /// both decide a session is new.
    @discardableResult
    func importFromHealth(userId: String, since: Date? = nil) async -> Int {
        let start = since ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let imported = await HealthKitService.shared.importCardioSessions(
            userId: userId, since: start
        )
        guard !imported.isEmpty else { return 0 }

        // Skip what is already known locally so the common case costs no writes.
        let knownUUIDs = Set(sessions.compactMap(\.healthKitUUID))
        let fresh = imported.filter { session in
            guard let uuid = session.healthKitUUID else { return false }
            return !knownUUIDs.contains(uuid)
        }
        guard !fresh.isEmpty else { return 0 }

        var count = 0
        for session in fresh where await save(session) {
            count += 1
        }
        return count
    }

    // MARK: - Mapping

    private func payload(from session: CardioSession) -> CardioUpsertPayload {
        CardioUpsertPayload(
            id: session.id,
            user_id: session.userId,
            modality: session.modality.rawValue,
            start_time: iso8601.string(from: session.startTime),
            end_time: iso8601.string(from: session.endTime),
            duration_seconds: session.durationSeconds,
            distance_miles: session.distanceMiles,
            active_calories: session.activeCalories,
            average_heart_rate: session.averageHeartRate,
            max_heart_rate: session.maxHeartRate,
            elevation_gain_feet: session.elevationGainFeet,
            notes: session.notes,
            healthkit_uuid: session.healthKitUUID,
            source_name: session.sourceName
        )
    }

    private func session(from row: CardioRow) -> CardioSession? {
        // A row whose modality the app does not recognize is skipped rather than
        // coerced into some default — showing a run as a row would be worse than
        // showing nothing. The DB check constraint should make this unreachable.
        guard let modality = CardioModality(rawValue: row.modality) else { return nil }

        func date(_ raw: String) -> Date? {
            iso8601.date(from: raw) ?? iso8601NoFraction.date(from: raw)
        }
        guard let start = date(row.startTime), let end = date(row.endTime) else { return nil }

        return CardioSession(
            id: row.id,
            userId: row.userId,
            modality: modality,
            startTime: start,
            endTime: end,
            durationSeconds: row.durationSeconds,
            distanceMiles: row.distanceMiles,
            activeCalories: row.activeCalories,
            averageHeartRate: row.averageHeartRate,
            maxHeartRate: row.maxHeartRate,
            elevationGainFeet: row.elevationGainFeet,
            notes: row.notes,
            healthKitUUID: row.healthkitUUID,
            sourceName: row.sourceName
        )
    }
}
