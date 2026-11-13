import Foundation
import SwiftUI

struct User: Decodable {
    let id: Int
    let email: String
    let username: String
    let firstName: String
    let lastName: String
    let role: String
    let emailVerified: Bool

    var displayName: String {
        let n = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? username : n
    }
}

struct MeResponse: Decodable { let user: User? }

enum ServerStatus {
    case running, offline, starting, stopping, suspended, unknown

    init(_ raw: String?) {
        switch (raw ?? "").lowercased() {
        case "running", "online": self = .running
        case "offline", "stopped": self = .offline
        case "starting": self = .starting
        case "stopping": self = .stopping
        case "suspended": self = .suspended
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .running: return "Online"
        case .offline: return "Offline"
        case .starting: return "Startet"
        case .stopping: return "Stoppt"
        case .suspended: return "Gesperrt"
        case .unknown: return "Unbekannt"
        }
    }

    var color: Color {
        switch self {
        case .running: return Tokens.ok
        case .starting, .stopping: return Tokens.warn
        case .offline, .suspended: return Tokens.bad
        case .unknown: return Tokens.dim
        }
    }
}

enum Provider { case game, kvm }

/// Ein Server in der Übersicht, entweder Gameserver oder KVM.
struct Service: Identifiable {
    let id: Int
    let name: String
    let plan: String?
    let status: ServerStatus
    let provider: Provider
    let shared: Bool
}

struct ServerListResponse: Decodable {
    let servers: [ServerRow]
}

struct ServerRow: Decodable {
    let id: Int
    let name: String
    let planName: String?
    let status: String?
    let provider: String?
    let shared: Bool

    enum K: String, CodingKey { case id, server_name, plan_name, status, provider, is_shared }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flex(.id)?.int ?? 0
        name = c.str(.server_name) ?? "Server"
        planName = c.str(.plan_name)
        status = c.str(.status)
        provider = c.str(.provider)
        shared = c.flex(.is_shared)?.string == "1" || c.flex(.is_shared)?.string == "true"
    }
}

struct TicketListResponse: Decodable { let tickets: [Ticket] }

struct Ticket: Decodable, Identifiable {
    let id: Int
    let subject: String
    let status: String
    let category: String?
    let lastMessage: String?
    let updatedAt: Date?

    enum K: String, CodingKey { case id, subject, status, category, last_message, updated_at, last_message_at }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flex(.id)?.int ?? 0
        subject = c.str(.subject) ?? "Ticket"
        status = c.str(.status) ?? "open"
        category = c.str(.category)
        lastMessage = c.str(.last_message)
        updatedAt = Ticket.date(c.str(.last_message_at) ?? c.str(.updated_at))
    }

    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    var statusLabel: String {
        switch status {
        case "open": return "Offen"
        case "answered": return "Beantwortet"
        case "pending": return "Wartet"
        case "closed": return "Geschlossen"
        case "archived": return "Archiviert"
        default: return status.capitalized
        }
    }
}

struct TicketDetailResponse: Decodable {
    let ticket: Ticket
    let messages: [TicketMessage]
}

struct TicketMessage: Decodable, Identifiable {
    let id: Int
    let text: String
    let isStaff: Bool
    let author: String?
    let createdAt: Date?

    enum K: String, CodingKey { case id, message, is_staff, username, created_at }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flex(.id)?.int ?? 0
        text = c.str(.message) ?? ""
        isStaff = c.flex(.is_staff)?.string == "true" || c.flex(.is_staff)?.string == "1"
        author = c.str(.username)
        createdAt = Ticket.date(c.str(.created_at))
    }
}
