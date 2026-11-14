import WidgetKit

enum StatusState {
    case data(WidgetSnapshot, locked: Bool, offline: Bool)
    case signedOut
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let state: StatusState
}

struct StatusProvider: TimelineProvider {
    /// Nur für die Widget-Galerie; im Betrieb kommen die Werte aus der API.
    func placeholder(in context: Context) -> StatusEntry {
        let demo = WidgetSnapshot(servers: [WidgetServer(name: "Server", state: "running"),
                                            WidgetServer(name: "Server", state: "running"),
                                            WidgetServer(name: "Server", state: "offline")], updated: Date())
        return StatusEntry(date: Date(), state: .data(demo, locked: false, offline: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await current()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let entry = await current()
            // Das System bestimmt das tatsächliche Intervall; 15 Minuten ist nur der Wunsch.
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    private func current() async -> StatusEntry {
        let locked = WidgetShare.lockOn
        let api = ApiClient.shared
        if api.hasToken {
            let r = await ServiceList.load(api)
            if r.error == nil {
                WidgetShare.save(r.services)
                let snap = WidgetSnapshot(servers: r.services.map { WidgetServer(name: $0.name, state: $0.status.key) },
                                          updated: Date())
                return StatusEntry(date: snap.updated, state: .data(snap, locked: locked, offline: false))
            }
            if let e = r.error as? ApiError, case .unauthorized = e { return StatusEntry(date: Date(), state: .signedOut) }
        }
        // Ohne Netz oder ohne geteilte Sitzung gilt der letzte Stand aus der App.
        if let snap = WidgetShare.load() {
            return StatusEntry(date: snap.updated, state: .data(snap, locked: locked, offline: api.hasToken))
        }
        return StatusEntry(date: Date(), state: .signedOut)
    }
}
