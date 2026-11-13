import Foundation

enum ApiError: LocalizedError {
    case emailNotVerified(String)
    case unauthorized
    case totpRequired
    case server(Int, String)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .emailNotVerified(let m): return m
        case .unauthorized: return "Nicht angemeldet. Bitte erneut einloggen."
        case .totpRequired: return "Bestätigungscode erforderlich."
        case .server(_, let m): return m
        case .network(let m): return "Netzwerkfehler: \(m)"
        case .decoding: return "Antwort des Servers nicht lesbar."
        }
    }
}
