import Foundation
import Supabase

// MARK: - Supabase migration (#317)
//
// Body measurements are stored in `body_measurements`. If this table does not
// yet exist in the project, running the service is safe: every call catches
// errors and returns an empty / no-op result so the UI degrades to its empty
// state. Apply the following SQL in Supabase to enable persistence:
//
// ```sql
// create table if not exists public.body_measurements (
//     id uuid primary key default gen_random_uuid(),
//     user_id uuid not null references auth.users(id) on delete cascade,
//     kind text not null,
//     value double precision not null,
//     recorded_at timestamptz not null default now(),
//     notes text
// );
//
// create index if not exists body_measurements_user_kind_idx
//     on public.body_measurements (user_id, kind, recorded_at desc);
//
// alter table public.body_measurements enable row level security;
//
// create policy "Users manage their own measurements"
//     on public.body_measurements
//     for all
//     using (auth.uid() = user_id)
//     with check (auth.uid() = user_id);
// ```

// MARK: - DB row

private struct BodyMeasurementRow: Codable {
    let id: String
    let userId: String
    let kind: String
    let value: Double
    let recordedAt: String  // ISO8601 from Supabase
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind
        case value
        case recordedAt = "recorded_at"
        case notes
    }
}

private struct BodyMeasurementInsertPayload: Encodable {
    let id: String
    let user_id: String
    let kind: String
    let value: Double
    let recorded_at: String
    let notes: String?
}

// MARK: - MeasurementsService

@MainActor
final class MeasurementsService {
    static let shared = MeasurementsService()

    private static let tableName = "body_measurements"

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    /// Fetch every measurement for `userId`, newest first. Returns `[]` on any failure
    /// (table missing, offline, RLS rejection) so the UI can render an empty state.
    func fetchAll(userId: String) async -> [BodyMeasurement] {
        do {
            let rows: [BodyMeasurementRow] = try await supabase
                .from(Self.tableName)
                .select()
                .eq("user_id", value: userId)
                .order("recorded_at", ascending: false)
                .execute()
                .value

            return rows.compactMap(decode)
        } catch {
            // Graceful degradation — table may not exist yet, or the user may be offline.
            return []
        }
    }

    /// Insert a new measurement. Returns the persisted row on success, or `nil` on failure
    /// (caller should surface a generic error rather than crashing).
    @discardableResult
    func insert(_ measurement: BodyMeasurement) async -> BodyMeasurement? {
        let payload = BodyMeasurementInsertPayload(
            id: measurement.id,
            user_id: measurement.userId,
            kind: measurement.kind.rawValue,
            value: measurement.value,
            recorded_at: iso8601.string(from: measurement.recordedAt),
            notes: measurement.notes
        )

        do {
            try await supabase
                .from(Self.tableName)
                .insert(payload)
                .execute()
            return measurement
        } catch {
            return nil
        }
    }

    /// Delete a measurement by id. Returns `true` on success, `false` otherwise.
    @discardableResult
    func delete(id: String, userId: String) async -> Bool {
        do {
            try await supabase
                .from(Self.tableName)
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Decoding

    private func decode(_ row: BodyMeasurementRow) -> BodyMeasurement? {
        guard let kind = MeasurementKind(rawValue: row.kind) else { return nil }
        let date = iso8601.date(from: row.recordedAt) ?? Date()
        return BodyMeasurement(
            id: row.id,
            userId: row.userId,
            kind: kind,
            value: row.value,
            recordedAt: date,
            notes: row.notes
        )
    }
}
