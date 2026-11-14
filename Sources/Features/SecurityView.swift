import SwiftUI

struct SecurityView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var lock: FaceLock
    @State private var info: SecurityInfo?
    @State private var error: String?
    @State private var lockError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.gap) {
                ErrorLine(text: error)
                ErrorLine(text: lockError)
                Card {
                    Toggle("Mit \(FaceLock.biometryName) sperren", isOn: Binding(
                        get: { lock.isOn },
                        set: { on in Task { lockError = await lock.setEnabled(on) } }))
                        .foregroundStyle(Tokens.text)
                }
                if let info {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Sicherheits-Mails", isOn: Binding(get: { info.securityAlertsEnabled }, set: { setAlerts($0) }))
                                .foregroundStyle(Tokens.text)
                            Text("Zwei-Faktor: \(info.totpEnabled ? "aktiv" : "aus")").font(.subheadline).foregroundStyle(Tokens.dim)
                            if info.failedLast24h > 0 {
                                Text("\(info.failedLast24h) fehlgeschlagene Logins in 24 h").font(.subheadline).foregroundStyle(Tokens.warn)
                            }
                        }
                    }
                    Text("Aktive Sitzungen").font(.headline).foregroundStyle(Tokens.text).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(info.sessions) { s in
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.device ?? "Gerät").font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.text)
                                    Text("\(s.ip ?? "") \(s.current ? "· dieses Gerät" : "")").font(.caption).foregroundStyle(Tokens.dim)
                                }
                                Spacer()
                                if !s.current {
                                    Button("Beenden") { revoke(s.id) }.font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.bad)
                                }
                            }
                        }
                    }
                    Text("Login-Verlauf").font(.headline).foregroundStyle(Tokens.text).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(info.loginHistory.enumerated()), id: \.offset) { _, e in
                        Card {
                            HStack {
                                Image(systemName: e.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(e.success ? Tokens.ok : Tokens.bad)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.device ?? e.ip).font(.subheadline).foregroundStyle(Tokens.text)
                                    Text("\(e.createdAt.prefix(16).replacingOccurrences(of: "T", with: " ")) · \(e.ip)").font(.caption).foregroundStyle(Tokens.dim)
                                }
                            }
                        }
                    }
                } else if error == nil {
                    ProgressView()
                }
            }
            .padding(Tokens.pad)
        }
        .background(Tokens.bg)
        .navigationTitle("Sicherheit")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { info = try await state.api.get("/api/account/security", as: SecurityInfo.self); error = nil }
        catch { self.error = "Sicherheitsdaten konnten nicht geladen werden." }
    }

    private func post(_ body: [String: Any]) {
        Task {
            do { try await state.api.send("POST", "/api/account/security", body: body); await load() }
            catch { self.error = "Aktion fehlgeschlagen." }
        }
    }

    private func revoke(_ id: String) { post(["action": "revoke_session", "sessionId": id]) }
    private func setAlerts(_ on: Bool) { post(["action": "set_alerts", "enabled": on]) }
}
