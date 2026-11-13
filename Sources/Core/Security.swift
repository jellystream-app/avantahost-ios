import Foundation

struct SecuritySession: Decodable, Identifiable {
    let id: String
    let current: Bool
    let device: String?
    let ip: String?
    let lastSeenAt: String?
}

struct LoginEvent: Decodable {
    let success: Bool
    let reason: String
    let ip: String
    let device: String?
    let createdAt: String
}

/// Antwort von GET /api/account/security
struct SecurityInfo: Decodable {
    let totpEnabled: Bool
    let securityAlertsEnabled: Bool
    let failedLast24h: Int
    let sessions: [SecuritySession]
    let loginHistory: [LoginEvent]
}
