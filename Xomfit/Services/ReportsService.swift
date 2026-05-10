import Foundation
import Supabase

// MARK: - ReportsService
//
// Thin REST client for the Reports API (#260). The backend is being built
// in parallel under `xomfit-backend` and lives behind the Supabase
// project's Functions endpoint:
//
//     <supabaseURL>/functions/v1/api/reports
//
// Auth: forwards the current Supabase session JWT as a Bearer token, plus
// the Supabase anon key as `apikey` (Edge Functions still require it).
//
// Resilience: until the backend ships, every endpoint returns "not found"
// and the service silently no-ops instead of surfacing errors to the UI.
// Network failures are also swallowed so the Reports tab loads to an
// empty state offline rather than a red error wall.

@MainActor
final class ReportsService {
    static let shared = ReportsService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        // Backend emits ISO-8601 with optional fractional seconds. Use
        // the value-typed `Date.ISO8601FormatStyle` parsers so the
        // strategy closure stays Sendable under strict concurrency.
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = try? Date(raw, strategy: .iso8601) { return date }
            if let date = try? Date(
                raw,
                strategy: .iso8601.year().month().day()
                    .dateTimeSeparator(.standard)
                    .time(includingFractionalSeconds: true)
            ) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized ISO-8601 date: \(raw)"
            )
        }
        self.decoder = dec

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
    }

    // MARK: - Public API

    /// Fetches reports for the signed-in user.
    /// Returns `[]` when the backend isn't deployed yet (404), the user
    /// is signed out, or the request fails for any reason.
    func fetchReports(kind: UserReport.ReportKind?) async throws -> [UserReport] {
        var query: [URLQueryItem] = []
        if let kind {
            query.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }

        do {
            let data = try await request(
                method: "GET",
                path: "/reports",
                query: query,
                body: Optional<EmptyBody>.none
            )
            return try decoder.decode([UserReport].self, from: data)
        } catch ReportsServiceError.notFound {
            // Backend hasn't shipped — degrade silently with an empty list.
            print("[ReportsService] /reports returned 404 — backend not deployed yet, returning [].")
            return []
        } catch ReportsServiceError.notAuthenticated {
            print("[ReportsService] No active session, returning [].")
            return []
        } catch {
            print("[ReportsService] fetchReports failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Marks a report as read. Silently no-ops on 404 (backend missing).
    func markRead(reportId: String) async throws {
        do {
            _ = try await request(
                method: "POST",
                path: "/reports/\(reportId)/read",
                query: [],
                body: Optional<EmptyBody>.none
            )
        } catch ReportsServiceError.notFound {
            print("[ReportsService] markRead 404 — no-op until backend ships.")
        } catch ReportsServiceError.notAuthenticated {
            print("[ReportsService] markRead skipped: not authenticated.")
        }
    }

    /// Submits feedback for a report. Silently no-ops on 404.
    func submitFeedback(reportId: String, rating: Int, text: String?) async throws {
        let payload = FeedbackPayload(rating: rating, text: text)
        do {
            _ = try await request(
                method: "POST",
                path: "/reports/\(reportId)/feedback",
                query: [],
                body: payload
            )
        } catch ReportsServiceError.notFound {
            print("[ReportsService] submitFeedback 404 — no-op until backend ships.")
        } catch ReportsServiceError.notAuthenticated {
            print("[ReportsService] submitFeedback skipped: not authenticated.")
        }
    }

    // MARK: - Private

    /// Resolves the backend base URL. Lives at the Supabase functions
    /// endpoint (e.g. `https://<ref>.supabase.co/functions/v1/api`).
    private func baseURL() throws -> URL {
        guard let supaURL = URL(string: Config.supabaseURL),
              let host = supaURL.host else {
            throw ReportsServiceError.invalidConfig
        }
        var components = URLComponents()
        components.scheme = supaURL.scheme ?? "https"
        components.host = host
        if let port = supaURL.port { components.port = port }
        components.path = "/functions/v1/api"
        guard let url = components.url else {
            throw ReportsServiceError.invalidConfig
        }
        return url
    }

    private func request<Body: Encodable>(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Body?
    ) async throws -> Data {
        let session = try await supabase.auth.session
        let token = session.accessToken
        guard !token.isEmpty else { throw ReportsServiceError.notAuthenticated }

        let base = try baseURL()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw ReportsServiceError.invalidConfig
        }
        components.path += path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw ReportsServiceError.invalidConfig }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await self.session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ReportsServiceError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 404:
            throw ReportsServiceError.notFound
        case 401, 403:
            throw ReportsServiceError.notAuthenticated
        default:
            throw ReportsServiceError.http(status: http.statusCode)
        }
    }

}

// MARK: - Errors

enum ReportsServiceError: LocalizedError {
    case invalidConfig
    case invalidResponse
    case notFound
    case notAuthenticated
    case http(status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfig:     "Reports backend isn't configured."
        case .invalidResponse:   "Unexpected response from reports backend."
        case .notFound:          "Reports backend not deployed."
        case .notAuthenticated:  "Sign in to view reports."
        case .http(let status):  "Reports backend error (HTTP \(status))."
        }
    }
}

// MARK: - Wire Types

private struct FeedbackPayload: Encodable {
    let rating: Int
    let text: String?
}

private struct EmptyBody: Encodable {}
