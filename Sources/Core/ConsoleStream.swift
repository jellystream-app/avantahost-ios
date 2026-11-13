import Foundation

struct ConsoleLine: Identifiable {
    let id: Int
    let text: String
    let system: Bool
}

/// Live-Konsole eines Game-Servers über SSE (/api/server-dashboard/[id]/console).
/// Events: state, line, stats, status, notice, end. Zeilen sind auf `limit` begrenzt.
@MainActor
final class ConsoleStream: ObservableObject {
    enum Phase { case connecting, online, failed(String) }

    @Published var lines: [ConsoleLine] = []
    @Published var phase: Phase = .connecting
    @Published var serverState: String?

    private let limit = 500
    private var counter = 0
    private var task: Task<Void, Never>?
    private let serverId: Int
    private let api: ApiClient

    init(serverId: Int, api: ApiClient) {
        self.serverId = serverId
        self.api = api
    }

    func start() {
        guard task == nil else { return }
        task = Task { await run() }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func send(_ command: String) async throws {
        try await api.send("POST", "/api/server-dashboard/\(serverId)/command", body: ["command": command])
    }

    private func run() async {
        var failures = 0
        while !Task.isCancelled {
            phase = .connecting
            var retry = true
            do {
                let bytes = try await api.openStream("/api/server-dashboard/\(serverId)/console")
                failures = 0
                for try await raw in bytes.lines {
                    if Task.isCancelled { return }
                    guard raw.hasPrefix("data:") else { continue }
                    let json = raw.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if let r = handle(String(json)), !r { retry = false; break }
                }
            } catch is CancellationError {
                return
            } catch ApiError.unauthorized {
                phase = .failed("Nicht angemeldet."); return
            } catch ApiError.server(let code, let msg) {
                phase = .failed(msg)
                if code != 429 { return }
            } catch {
                if Task.isCancelled { return }
                failures += 1
                if failures >= 4 { phase = .failed("Verbindung verloren."); return }
            }
            if !retry { return }
            try? await Task.sleep(nanoseconds: UInt64(min(failures + 1, 5)) * 2_000_000_000)
        }
    }

    /// Gibt false zurück, wenn der Server keinen Neuversuch will.
    private func handle(_ json: String) -> Bool? {
        guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any],
              let type = obj["type"] as? String else { return nil }
        switch type {
        case "state":
            if obj["state"] as? String == "online" { phase = .online }
        case "line":
            if let l = obj["line"] as? String { append(Self.strip(l), system: false) }
        case "status":
            serverState = obj["state"] as? String
        case "notice":
            if let m = obj["message"] as? String { append(m, system: true) }
        case "end":
            if let m = obj["message"] as? String, !m.isEmpty { append(m, system: true) }
            return (obj["retry"] as? Bool) ?? true
        default: break
        }
        return nil
    }

    private func append(_ text: String, system: Bool) {
        counter += 1
        lines.append(ConsoleLine(id: counter, text: text, system: system))
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
    }

    /// ANSI-Farbcodes entfernen.
    static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
    }
}
