import Foundation

struct WidgetServer: Codable, Hashable {
    let name: String
    let state: String
}

struct WidgetSnapshot: Codable {
    let servers: [WidgetServer]
    let updated: Date
}

extension ServerStatus {
    var key: String {
        switch self {
        case .running: return "running"
        case .offline: return "offline"
        case .starting: return "starting"
        case .stopping: return "stopping"
        case .suspended: return "suspended"
        case .unknown: return "unknown"
        }
    }
}

/// Austausch zwischen App und Widget über den App-Group-Container.
/// Ohne passende Berechtigung ist containerURL nil, dann bleibt alles stumm leer.
enum WidgetShare {
    /// Beim Sideload hängt die Signierung die Team-ID an die Bundle-ID, deshalb wird die Gruppe zur Laufzeit abgeleitet.
    static var groupId: String? {
        guard var id = Bundle.main.bundleIdentifier else { return nil }
        if Bundle.main.bundleURL.pathExtension == "appex" {
            id = id.split(separator: ".").dropLast().joined(separator: ".")
        }
        return "group." + id
    }

    private static func file(_ name: String) -> URL? {
        guard let g = groupId,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) else { return nil }
        return dir.appendingPathComponent(name)
    }

    private static func write(_ data: Data, _ name: String) {
        try? file(name).map { try data.write(to: $0, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    static func save(_ services: [Service]) {
        let snap = WidgetSnapshot(servers: services.map { WidgetServer(name: $0.name, state: $0.status.key) }, updated: Date())
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(snap) { write(d, "snapshot.json") }
    }

    static func load() -> WidgetSnapshot? {
        guard let url = file("snapshot.json"), let d = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(WidgetSnapshot.self, from: d)
    }

    static func clear() {
        if let url = file("snapshot.json") { try? FileManager.default.removeItem(at: url) }
    }

    /// Spiegel des Face-ID-Schalters; fehlt er, gilt die Sperre als aktiv.
    static func setLock(_ on: Bool) {
        write(Data((on ? "1" : "0").utf8), "lock.flag")
    }

    static var lockOn: Bool {
        guard let url = file("lock.flag"), let s = try? String(contentsOf: url, encoding: .utf8) else { return true }
        return s != "0"
    }
}
