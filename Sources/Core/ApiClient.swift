import Foundation

/// Spricht mit avantahost.de und schickt das Session-Cookie selbst mit.
/// Es wird bewusst kein Origin-Header gesetzt, sonst lehnt die CSRF-Prüfung des Servers ab.
final class ApiClient {
    static let shared = ApiClient()
    static let base = URL(string: "https://avantahost.de")!
    private static let cookieName = "session_token"
    private static let tokenKey = "session_token"

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieStorage = nil
        cfg.httpShouldSetCookies = false
        cfg.httpCookieAcceptPolicy = .never
        cfg.timeoutIntervalForRequest = 25
        cfg.httpAdditionalHeaders = ["Accept": "application/json", "User-Agent": "AvantahostiOS/0.1"]
        session = URLSession(configuration: cfg)
    }

    var hasToken: Bool { token != nil }

    /// Nur ein Token ohne ; , Leerzeichen und Steuerzeichen darf in den Cookie-Header.
    private var token: String? {
        guard let t = Keychain.read(Self.tokenKey), Self.valid(t) else { return nil }
        return t
    }

    private static func valid(_ t: String) -> Bool {
        guard !t.isEmpty, t.utf8.count <= 4096 else { return false }
        return t.unicodeScalars.allSatisfy { $0.value > 32 && $0.value < 127 && $0 != ";" && $0 != "," }
    }

    /// Liest session_token aus den Set-Cookie-Headern, zuerst per HTTPCookie, dann per eigenem Parser.
    private static func cookieValue(from resp: HTTPURLResponse) -> String? {
        let raws = SessionCookie.headerValues(resp)
        let fields = ["Set-Cookie": raws.joined(separator: ", ")]
        let url = resp.url ?? base
        for c in HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        where c.name == cookieName && valid(c.value) { return c.value }
        guard let v = SessionCookie.value(named: cookieName, in: raws), valid(v) else { return nil }
        return v
    }

    func clearSession() {
        Keychain.delete(Self.tokenKey)
    }

    // MARK: Request

    @discardableResult
    func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        try await request(method, path, body: body).0
    }

    private func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: path, relativeTo: Self.base)!)
        req.httpMethod = method
        if let t = token { req.setValue("\(Self.cookieName)=\(t)", forHTTPHeaderField: "Cookie") }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: req) }
        catch { throw ApiError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw ApiError.network("Keine HTTP-Antwort") }
        let status = http.statusCode
        if (200..<300).contains(status) { return (data, http) }

        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = obj?["error"] as? String ?? "Fehler \(status)"
        if status == 403, obj?["code"] as? String == "EMAIL_NOT_VERIFIED" { throw ApiError.emailNotVerified(message) }
        if status == 401, obj?["totpRequired"] as? Bool == true { throw ApiError.totpRequired }
        if status == 401, path != "/api/auth/login" { throw ApiError.unauthorized }
        throw ApiError.server(status, message)
    }

    /// Offener Byte-Stream (SSE) mit Session-Cookie. Der Aufrufer bricht über Task-Cancel ab.
    func openStream(_ path: String) async throws -> URLSession.AsyncBytes {
        var req = URLRequest(url: URL(string: path, relativeTo: Self.base)!)
        req.timeoutInterval = 60
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let t = token { req.setValue("\(Self.cookieName)=\(t)", forHTTPHeaderField: "Cookie") }
        let bytes: URLSession.AsyncBytes, resp: URLResponse
        do { (bytes, resp) = try await session.bytes(for: req) }
        catch { throw ApiError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw ApiError.network("Keine HTTP-Antwort") }
        switch http.statusCode {
        case 200..<300: return bytes
        case 401: throw ApiError.unauthorized
        case 403: throw ApiError.server(403, "Keine Berechtigung für die Konsole.")
        case 429: throw ApiError.server(429, "Zu viele offene Konsolen. Gleich nochmal versuchen.")
        default: throw ApiError.server(http.statusCode, "Konsole nicht erreichbar (\(http.statusCode)).")
        }
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let data = try await send("GET", path)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw ApiError.decoding }
    }

    // MARK: Auth

    func login(email: String, password: String, totp: String?) async throws {
        var body: [String: Any] = ["email": email, "password": password]
        if let totp, !totp.isEmpty { body["totpCode"] = totp }
        let (data, http) = try await request("POST", "/api/auth/login", body: body)
        guard let value = Self.cookieValue(from: http) else {
            let hasHeader = !SessionCookie.headerValues(http).isEmpty
            let why = hasHeader ? "Set-Cookie ohne gueltiges session_token" : "Header Set-Cookie fehlt"
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let ok = obj?["success"] as? Bool == true ? "success:true" : "success nicht true"
            let server = obj?["error"] as? String
            var msg = "Login ohne Session-Cookie (HTTP \(http.statusCode), \(why), \(ok)). Header: \(SessionCookie.headerNames(http))."
            if let server { msg = server + " " + msg }
            throw ApiError.server(http.statusCode, msg)
        }
        Keychain.write(Self.tokenKey, value)
    }

    func logout() async {
        _ = try? await send("POST", "/api/auth/logout")
        clearSession()
    }

    func resendVerification() async throws {
        try await send("POST", "/api/auth/verify-email")
    }
}
