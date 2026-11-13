import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject var state: AppState
    let service: Service
    @State private var detail: ServerDetail?
    @State private var error: String?
    @State private var busyAction: String?
    @State private var confirmStop = false

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.gap) {
                header
                ErrorLine(text: error)
                if let d = detail {
                    actions(d)
                    if service.provider == .game { consoleLink }
                    usage(d)
                    if !d.rows.isEmpty { info(d) }
                } else if error == nil {
                    ProgressView().padding(.top, 40)
                }
            }
            .padding(Tokens.pad)
        }
        .background(Tokens.bg)
        .navigationTitle(service.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("Server wirklich stoppen?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stoppen", role: .destructive) { Task { await run("stop") } }
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: 12) {
                IconTile(symbol: service.provider == .kvm ? "server.rack" : "gamecontroller.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name).font(.title3.weight(.bold)).foregroundStyle(Tokens.text)
                    if let p = service.plan { Text(p).font(.subheadline).foregroundStyle(Tokens.dim) }
                }
                Spacer()
                StatusBadge(status: detail?.status ?? service.status)
            }
        }
    }

    private func actions(_ d: ServerDetail) -> some View {
        HStack(spacing: 10) {
            PillButton(title: "Start", symbol: "play.fill", tint: Tokens.ok, busy: busyAction == "start") {
                Task { await run("start") }
            }
            PillButton(title: "Neustart", symbol: "arrow.clockwise", busy: busyAction == "restart") {
                Task { await run("restart") }
            }
            PillButton(title: "Stopp", symbol: "stop.fill", tint: Tokens.bad, busy: busyAction == "stop") {
                confirmStop = true
            }
        }
        .disabled(busyAction != nil || d.status == .suspended)
    }

    private var consoleLink: some View {
        NavigationLink {
            ConsoleView(serverId: service.id, api: state.api)
        } label: {
            Card {
                HStack(spacing: 12) {
                    IconTile(symbol: "terminal.fill")
                    Text("Konsole").font(.headline).foregroundStyle(Tokens.text)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Tokens.dim)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func usage(_ d: ServerDetail) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Auslastung").font(.footnote.weight(.semibold)).foregroundStyle(Tokens.dim)
                if let c = d.cpu {
                    UsageBar(title: "CPU", value: d.cpuMax.map { c / $0 } ?? min(c / 100, 1),
                             detail: String(format: "%.0f %%", c))
                }
                if let u = d.ramUsed {
                    UsageBar(title: "RAM", value: d.ramMax.map { u / $0 } ?? 0, detail: pair(u, d.ramMax))
                }
                if let u = d.diskUsed {
                    UsageBar(title: "Speicher", value: d.diskMax.map { u / $0 } ?? 0, detail: pair(u, d.diskMax))
                }
                if let up = d.uptime, up > 0 {
                    HStack {
                        Text("Laufzeit").font(.subheadline).foregroundStyle(Tokens.dim)
                        Spacer()
                        Text(uptimeText(up)).font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.text)
                    }
                }
            }
        }
    }

    private func info(_ d: ServerDetail) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Konfiguration").font(.footnote.weight(.semibold)).foregroundStyle(Tokens.dim)
                ForEach(d.rows, id: \.0) { row in
                    HStack {
                        Text(row.0).foregroundStyle(Tokens.dim)
                        Spacer()
                        Text(row.1).foregroundStyle(Tokens.text).textSelection(.enabled)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func pair(_ used: Double, _ max: Double?) -> String {
        guard let max else { return mb(used) }
        return "\(mb(used)) / \(mb(max))"
    }

    private func mb(_ v: Double) -> String { v >= 1024 ? String(format: "%.1f GB", v / 1024) : String(format: "%.0f MB", v) }

    private func uptimeText(_ s: Double) -> String {
        let t = Int(s), d = t / 86400, h = (t % 86400) / 3600, m = (t % 3600) / 60
        return d > 0 ? "\(d) T \(h) Std" : h > 0 ? "\(h) Std \(m) Min" : "\(m) Min"
    }

    private func load() async {
        do { detail = try await ServerDetailLoader.load(service, api: state.api); error = nil }
        catch ApiError.unauthorized { await state.refreshUser() }
        catch { self.error = error.localizedDescription }
    }

    private func run(_ action: String) async {
        busyAction = action; error = nil
        defer { busyAction = nil }
        do {
            try await ServerDetailLoader.power(service, action, api: state.api)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
