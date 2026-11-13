import SwiftUI

@MainActor
final class DashboardModel: ObservableObject {
    @Published var services: [Service] = []
    @Published var loading = false
    @Published var error: String?
    @Published var unverified = false

    func load(_ api: ApiClient) async {
        loading = true; error = nil
        defer { loading = false }
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
        services = all
        if all.isEmpty, let e = firstError { error = e.localizedDescription }
        await refreshGameStatus(api)
        QuickActions.shared.update(services)
    }

    /// Die Liste der Gameserver enthält nur "active", nicht ob der Server wirklich läuft.
    /// Den echten Zustand gibt es nur pro Server, deshalb wird er hier einzeln nachgeladen.
    private func refreshGameStatus(_ api: ApiClient) async {
        let games = services.filter { $0.provider == .game }
        guard !games.isEmpty else { return }
        let live: [Int: ServerStatus] = await withTaskGroup(of: (Int, ServerStatus?).self) { group in
            for s in games {
                group.addTask { (s.id, try? await ServerDetailLoader.load(s, api: api).status) }
            }
            var out: [Int: ServerStatus] = [:]
            for await (id, st) in group { if let st { out[id] = st } }
            return out
        }
        services = services.map { s in
            guard s.provider == .game, let st = live[s.id] else { return s }
            return Service(id: s.id, name: s.name, plan: s.plan, status: st, provider: .game, shared: s.shared)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var platform: PlatformStatus
    @StateObject private var model = DashboardModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    ScreenTitle(text: "Übersicht")
                    if let m = platform.message {
                        Card { Text(m).font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.warn) }
                    }
                    ErrorLine(text: model.error)
                    if model.services.isEmpty && !model.loading && model.error == nil {
                        Card { Text("Noch keine Server.").foregroundStyle(Tokens.dim) }
                    }
                    ForEach(model.services) { s in
                        NavigationLink(value: s.id * 10 + (s.provider == .kvm ? 1 : 0)) { ServiceCard(service: s) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Tokens.pad)
            }
            .background(Tokens.bg)
            .refreshable { await model.load(state.api) }
            .navigationDestination(for: Int.self) { key in
                if let s = model.services.first(where: { $0.id * 10 + ($0.provider == .kvm ? 1 : 0) == key }) {
                    ServerDetailView(service: s)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay { if model.loading && model.services.isEmpty { ProgressView() } }
        }
        .task { await model.load(state.api) }
    }
}

struct ServiceCard: View {
    let service: Service
    var body: some View {
        Card {
            HStack(spacing: 12) {
                IconTile(symbol: service.provider == .kvm ? "server.rack" : "gamecontroller.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name).font(.headline).foregroundStyle(Tokens.text)
                    Text([service.plan, service.shared ? "Freigabe" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Tokens.dim)
                }
                Spacer()
                StatusBadge(status: service.status)
            }
        }
    }
}
