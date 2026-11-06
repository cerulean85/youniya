import Foundation

// MARK: - Configuration

enum APIConfig {
    /// Debug: the home-desktop dev server over Tailscale (dev sign-in, trusted
    /// purchases, minimum version 0.1). Release/TestFlight: the production API
    /// (HTTPS, minimum version 1.0.0, no dev sign-in, StoreKit-verified purchases).
    /// Override with `-apiBaseURL http://…` (launch argument) or the `apiBaseURL` default.
    #if DEBUG
    static let defaultBaseURL = "http://100.126.111.107:8000"
    #else
    static let defaultBaseURL = "https://youniya-api.dycdyp.com"
    #endif

    static var baseURL: URL {
        let s = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
        return URL(string: s) ?? URL(string: defaultBaseURL)!
    }

    /// Sent as `X-App-Version`; the server answers 426 below its minimum (40).
    static var appVersion: String {
        #if DEBUG
        // `-appVersionOverride 1.0.0` to test 40, or to get past a dev server's minimum.
        if let v = UserDefaults.standard.string(forKey: "appVersionOverride") { return v }
        #endif
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}

// MARK: - Errors

/// The server's `{"error": {"code", "message", …}}`. `message` is Korean copy
/// that can be shown as is.
struct APIError: Error, LocalizedError, Equatable {
    var status: Int
    var code: String
    var message: String
    /// 503 maintenance: when it ends.
    var until: Date?

    var errorDescription: String? { message }

    static let offline = APIError(status: 0, code: "offline", message: "서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.")
    static let badResponse = APIError(status: 0, code: "bad_response", message: "응답을 읽지 못했어요.")
    static let signedOut = APIError(status: 401, code: "signed_out", message: "다시 로그인해 주세요.")
}

private struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        var code: String
        var message: String
        var until: String?
    }
    var error: Body
}

// MARK: - Auth payloads

/// `{access_token, refresh_token, user_id, needs_consent}`
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var needsConsent: Bool
}

// MARK: - Client

/// Talks to the YOUNIYA API: JSON in snake_case, Bearer access tokens that
/// are refreshed once on 401 `token_expired` (the refresh token rotates on
/// every use, so the new one is always saved).
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var tokens: AuthSession?
    /// One refresh at a time; concurrent 401s wait for the same one.
    private var refreshing: Task<AuthSession, Error>?

    init(session: URLSession = .shared) {
        self.session = session
        self.tokens = TokenStore.load()
    }

    var isSignedIn: Bool { tokens != nil }

    // MARK: Auth

    /// Development sign-in (`DEV_LOGIN=1` on the server): the same name is the same account.
    func devSignIn(name: String) async throws -> AuthSession {
        let s: AuthSession = try await send("POST", "/v1/auth/dev", body: ["name": name], authorized: false)
        store(s)
        return s
    }

    /// Apple or Google: the provider's ID token. TODO: Wire up Sign in with Apple / Google.
    func signIn(provider: String, idToken: String) async throws -> AuthSession {
        let s: AuthSession = try await send("POST", "/v1/auth/\(provider)", body: ["id_token": idToken], authorized: false)
        store(s)
        return s
    }

    /// Ends the server session and forgets the tokens, even when offline.
    func signOut() async {
        if let refresh = tokens?.refreshToken {
            _ = try? await sendRaw("POST", "/v1/auth/logout", body: ["refresh_token": refresh], authorized: false)
        }
        store(nil)
    }

    /// Forgets the tokens without telling the server (after the account is deleted).
    func forget() { store(nil) }

    private func store(_ s: AuthSession?) {
        tokens = s
        TokenStore.save(s)
    }

    // MARK: Requests

    func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
        try await send("GET", path, query: query)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await send("POST", path, body: body)
    }

    func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await send("PUT", path, body: body)
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await send("PATCH", path, body: body)
    }

    /// For 204 responses.
    func delete(_ path: String) async throws {
        _ = try await sendRaw("DELETE", path)
    }

    func send<T: Decodable>(_ method: String, _ path: String, query: [String: String?] = [:],
                            body: (any Encodable)? = nil, authorized: Bool = true) async throws -> T {
        let data = try await sendRaw(method, path, query: query, body: body, authorized: authorized)
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("APIClient decode \(method) \(path): \(error)")
            #endif
            throw APIError.badResponse
        }
    }

    /// Sends a request; on 401 `token_expired` refreshes once and retries.
    @discardableResult
    func sendRaw(_ method: String, _ path: String, query: [String: String?] = [:],
                 body: (any Encodable)? = nil, authorized: Bool = true) async throws -> Data {
        let request = try makeRequest(method, path, query: query, body: body, authorized: authorized)
        let (data, status) = try await perform(request)
        if (200..<300).contains(status) { return data }

        let error = decodeError(data, status: status)
        guard authorized, status == 401, error.code == "token_expired" else { throw error }

        // Access token expired: refresh, then try once more.
        _ = try await refreshTokens()
        let retry = try makeRequest(method, path, query: query, body: body, authorized: authorized)
        let (data2, status2) = try await perform(retry)
        if (200..<300).contains(status2) { return data2 }
        throw decodeError(data2, status: status2)
    }

    private func refreshTokens() async throws -> AuthSession {
        if let refreshing { return try await refreshing.value }
        guard let refresh = tokens?.refreshToken else { throw APIError.signedOut }
        let task = Task { () throws -> AuthSession in
            let request = try makeRequest("POST", "/v1/auth/refresh", query: [:],
                                          body: ["refresh_token": refresh], authorized: false)
            let (data, status) = try await perform(request)
            guard (200..<300).contains(status) else { throw decodeError(data, status: status) }
            guard let s = try? JSONCoding.decoder.decode(AuthSession.self, from: data) else { throw APIError.badResponse }
            return s
        }
        refreshing = task
        defer { refreshing = nil }
        do {
            let s = try await task.value
            store(s)
            return s
        } catch let e as APIError where e.status == 401 {
            // The refresh token is gone or expired: the user has to sign in again (39).
            store(nil)
            throw APIError(status: 401, code: "token_expired", message: e.message)
        }
    }

    private func makeRequest(_ method: String, _ path: String, query: [String: String?],
                             body: (any Encodable)?, authorized: Bool) throws -> URLRequest {
        var components = URLComponents(url: APIConfig.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }
        if !items.isEmpty { components.queryItems = items.sorted { $0.name < $1.name } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConfig.appVersion, forHTTPHeaderField: "X-App-Version")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encoder.encode(body)
        }
        if authorized {
            guard let access = tokens?.accessToken else { throw APIError.signedOut }
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            #if DEBUG
            print("APIClient \(request.httpMethod ?? "") \(request.url?.path() ?? ""): \(error)")
            #endif
            throw APIError.offline
        }
    }

    private nonisolated func decodeError(_ data: Data, status: Int) -> APIError {
        guard let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) else {
            return APIError(status: status, code: "http_\(status)", message: "요청을 처리하지 못했어요. (\(status))")
        }
        return APIError(status: status, code: env.error.code, message: env.error.message,
                        until: env.error.until.flatMap(JSONCoding.date(from:)))
    }
}

// MARK: - JSON

enum JSONCoding {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            guard let date = date(from: s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
            }
            return date
        }
        return d
    }()

    /// Python `isoformat()`: "2026-11-06T09:20:30.123456+00:00", fractions optional.
    static func date(from s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        // ISO8601DateFormatter reads at most milliseconds; trim microseconds.
        let trimmed = s.replacing(/(\.\d{3})\d+/) { $0.output.1 }
        return withFraction.date(from: trimmed) ?? plain.date(from: trimmed)
    }
}
