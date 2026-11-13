import Foundation

/// Gesamtstatus der Plattform aus /api/status (öffentlich, kein Login nötig).
@MainActor
final class PlatformStatus: ObservableObject {
    @Published var overall = "operational"

    private struct Report: Decodable { let overall: String }

    func refresh(api: ApiClient) async {
        if let r = try? await api.get("/api/status", as: Report.self) { overall = r.overall }
    }

    var message: String? {
        switch overall {
        case "degraded": return "Einzelne Dienste sind eingeschränkt."
        case "outage": return "Es gibt eine Störung. Wir arbeiten daran."
        default: return nil
        }
    }
}
