import Foundation

/// Einheitliche Sicht auf Game- und KVM-Server für die Detailansicht.
struct ServerDetail {
    var status: ServerStatus
    var cpu: Double?        // Prozent (0...)
    var cpuMax: Double?     // Prozent-Limit (Game: 100 pro Kern), KVM: 100
    var ramUsed: Double?    // MB
    var ramMax: Double?     // MB
    var diskUsed: Double?   // MB
    var diskMax: Double?    // MB
    var uptime: Double?     // Sekunden
    var rows: [(String, String)] = []
}

private func num(_ any: Any?) -> Double? {
    if let d = any as? Double { return d }
    if let s = any as? String { return Double(s) }
    if let i = any as? Int { return Double(i) }
    return nil
}

enum ServerDetailLoader {
    static func load(_ s: Service, api: ApiClient) async throws -> ServerDetail {
        switch s.provider {
        case .game: return try await game(s, api)
        case .kvm: return try await kvm(s, api)
        }
    }

    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private static func game(_ s: Service, _ api: ApiClient) async throws -> ServerDetail {
        let root = json(try await api.send("GET", "/api/server-dashboard/\(s.id)"))
        let res = root["resources"] as? [String: Any] ?? [:]
        let r = res["resources"] as? [String: Any] ?? [:]
        let panel = root["panelServer"] as? [String: Any] ?? [:]
        let lim = panel["limits"] as? [String: Any] ?? [:]
        var state = ServerStatus(res["currentState"] as? String)
        if res["isSuspended"] as? Bool == true { state = .suspended }
        var d = ServerDetail(status: state)
        d.cpu = num(r["cpuAbsolute"])
        let cpuLimit = num(lim["cpu"])
        d.cpuMax = (cpuLimit ?? 0) > 0 ? cpuLimit : nil
        d.ramUsed = num(r["memoryBytes"]).map { $0 / 1_048_576 }
        d.ramMax = num(lim["memory"]).flatMap { $0 > 0 ? $0 : nil }
        d.diskUsed = num(r["diskBytes"]).map { $0 / 1_048_576 }
        d.diskMax = num(lim["disk"]).flatMap { $0 > 0 ? $0 : nil }
        d.uptime = num(r["uptime"]).map { $0 / 1000 }
        if let allocs = panel["allocations"] as? [[String: Any]],
           let a = allocs.first(where: { $0["isDefault"] as? Bool == true }) ?? allocs.first,
           let ip = (a["alias"] as? String) ?? (a["ip"] as? String), let port = a["port"] {
            d.rows.append(("Adresse", "\(ip):\(port)"))
        }
        return d
    }

    private static func kvm(_ s: Service, _ api: ApiClient) async throws -> ServerDetail {
        let root = json(try await api.send("GET", "/api/servers/\(s.id)"))
        let sv = root["server"] as? [String: Any] ?? [:]
        var d = ServerDetail(status: ServerStatus(sv["status"] as? String))
        let usage = sv["fireapi_usage"] as? [String: Any]
        func data(_ k: String) -> Double? { num((usage?[k] as? [String: Any])?["data"]) }
        d.cpu = data("cpu"); d.cpuMax = 100
        d.ramUsed = data("mem").map { $0 * 1024 }          // kommt in GB
        d.ramMax = num(sv["fireapi_mem"])                   // MB
        d.diskUsed = data("nvme_storage").map { $0 * 1024 }
        d.diskMax = num(sv["fireapi_disk"]).map { $0 * 1024 }
        d.uptime = num(sv["fireapi_uptime"])
        if let v = sv["fireapi_primary_ipv4"] as? String, !v.isEmpty { d.rows.append(("IPv4", v)) }
        if let v = sv["fireapi_os"] as? String, !v.isEmpty { d.rows.append(("System", v)) }
        if let c = num(sv["fireapi_cores"]) { d.rows.append(("Kerne", String(Int(c)))) }
        if let l = sv["fireapi_location"] as? String, !l.isEmpty { d.rows.append(("Standort", l)) }
        return d
    }

    /// Start, Stopp oder Neustart. Gameserver und KVM haben dafür unterschiedliche Routen.
    static func power(_ s: Service, _ action: String, api: ApiClient) async throws {
        switch s.provider {
        case .game: try await api.send("POST", "/api/server-dashboard/\(s.id)/power", body: ["signal": action])
        case .kvm: try await api.send("POST", "/api/servers/\(s.id)", body: ["action": action])
        }
    }
}
