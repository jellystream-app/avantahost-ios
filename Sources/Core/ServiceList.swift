import Foundation

/// Serverliste für Übersicht und Widget.
enum ServiceList {
    /// Der Fehler kommt nur zurück, wenn gar kein Server geladen werden konnte.
    static func load(_ api: ApiClient) async -> (services: [Service], error: Error?) {
        var all: [Service] = []
        var firstError: Error?
        do {
            let g: ServerListResponse = try await api.get("/api/server-dashboard")
            all += g.servers.map { Service(id: $0.id, name: $0.name, plan: $0.planName, status: ServerStatus($0.status),
                                           provider: .game, shared: $0.shared) }
        } catch { firstError = error }
        do {
            let k: ServerListResponse = try await api.get("/api/servers")
            all += k.servers.filter { $0.provider == "fireapi" }.map {
                Service(id: $0.id, name: $0.name, plan: $0.planName, status: ServerStatus($0.status),
                        provider: .kvm, shared: $0.shared)
            }
        } catch { firstError = firstError ?? error }
        return (await withLiveStatus(all, api), all.isEmpty ? firstError : nil)
    }

    /// Die Liste der Gameserver enthält nur "active", nicht ob der Server wirklich läuft.
    /// Den echten Zustand gibt es nur pro Server, deshalb wird er hier einzeln nachgeladen.
    private static func withLiveStatus(_ services: [Service], _ api: ApiClient) async -> [Service] {
        let games = services.filter { $0.provider == .game }
        guard !games.isEmpty else { return services }
        let live: [Int: ServerStatus] = await withTaskGroup(of: (Int, ServerStatus?).self) { group in
            for s in games {
                group.addTask { (s.id, try? await ServerDetailLoader.load(s, api: api).status) }
            }
            var out: [Int: ServerStatus] = [:]
            for await (id, st) in group { if let st { out[id] = st } }
            return out
        }
        return services.map { s in
            guard s.provider == .game, let st = live[s.id] else { return s }
            return Service(id: s.id, name: s.name, plan: s.plan, status: st, provider: .game, shared: s.shared)
        }
    }
}
