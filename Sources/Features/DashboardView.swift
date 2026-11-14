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
        let r = await ServiceList.load(api)
        services = r.services
        if let e = r.error { error = e.localizedDescription }
        WidgetShare.publish(services)
        QuickActions.shared.update(services)
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
