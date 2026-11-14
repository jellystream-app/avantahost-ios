import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.gap) {
                if case .ready(let u) = state.phase { ProfileCard(user: u) }
                EmailChangeCard()
                AlertMailCard()
                DeletionCard()
            }
            .padding(Tokens.pad)
        }
        .background(Tokens.bg)
        .navigationTitle("Kontodaten")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ---------- Bausteine ----------

private struct ProfileCard: View {
    let user: User
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconTile(symbol: "person.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.displayName).font(.headline).foregroundStyle(Tokens.text)
                        Text(user.email).font(.subheadline).foregroundStyle(Tokens.dim)
                    }
                    Spacer()
                }
                Label(user.emailVerified ? "E-Mail bestätigt" : "E-Mail nicht bestätigt",
                      systemImage: user.emailVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(user.emailVerified ? Tokens.ok : Tokens.warn)
                Text("Benutzername: \(user.username)").font(.subheadline).foregroundStyle(Tokens.dim)
            }
        }
    }
}

private struct InputField: View {
    let title: String
    @Binding var text: String
    var secure = false
    var email = false
    var code = false

    var body: some View {
        Group {
            if secure { SecureField(title, text: $text) }
            else {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(email ? .emailAddress : code ? .numberPad : .default)
            }
        }
        .padding(14)
        .background(Tokens.bg, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
        .foregroundStyle(Tokens.text)
    }
}

private func json(_ data: Data) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

// ---------- E-Mail ändern ----------

private struct EmailChangeCard: View {
    @EnvironmentObject var state: AppState
    @State private var newEmail = ""
    @State private var password = ""
    @State private var code = ""
    @State private var totpEnabled = false
    @State private var pendingEmail: String?
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("E-Mail-Adresse ändern").font(.headline).foregroundStyle(Tokens.text)
                if let pendingEmail {
                    Text("Ausstehend: \(pendingEmail). Öffne den Bestätigungslink in der Mail an die neue Adresse.")
                        .font(.subheadline).foregroundStyle(Tokens.warn)
                }
                InputField(title: "Neue E-Mail-Adresse", text: $newEmail, email: true)
                InputField(title: "Passwort", text: $password, secure: true)
                if totpEnabled { InputField(title: "Bestätigungscode (2FA)", text: $code, code: true) }
                ErrorLine(text: error)
                if let info { Text(info).font(.footnote).foregroundStyle(Tokens.ok) }
                PrimaryButton(title: "Bestätigungslink anfordern", busy: busy) { submit() }
                    .disabled(newEmail.isEmpty || password.isEmpty)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let data = try? await state.api.send("GET", "/api/account/email-change") else { return }
        let o = json(data)
        totpEnabled = o["totpEnabled"] as? Bool ?? false
        pendingEmail = (o["pending"] as? [String: Any])?["newEmail"] as? String
    }

    private func submit() {
        busy = true; error = nil; info = nil
        var body: [String: Any] = ["newEmail": newEmail.trimmingCharacters(in: .whitespaces), "password": password]
        if totpEnabled { body["code"] = code }
        Task {
            defer { busy = false }
            do {
                let data = try await state.api.send("POST", "/api/account/email-change", body: body)
                info = json(data)["message"] as? String ?? "Bestätigungslink gesendet."
                password = ""; code = ""; newEmail = ""
                await load()
            } catch { self.error = error.localizedDescription }
        }
    }
}

// ---------- Ausfall-Mails ----------

private struct AlertMailCard: View {
    @EnvironmentObject var state: AppState
    @State private var enabled: Bool?
    @State private var error: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Ausfall-Mails für Server", isOn: Binding(
                    get: { enabled ?? false },
                    set: { set($0) }))
                    .disabled(enabled == nil)
                    .foregroundStyle(Tokens.text)
                Text("Eine Mail, wenn einer deiner Server nicht erreichbar ist.")
                    .font(.footnote).foregroundStyle(Tokens.dim)
                ErrorLine(text: error)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let data = try await state.api.send("GET", "/api/account/server-alerts")
            enabled = (json(data)["prefs"] as? [String: Any])?["emailEnabled"] as? Bool
            error = nil
        } catch { self.error = "Einstellung konnte nicht geladen werden." }
    }

    private func set(_ on: Bool) {
        let before = enabled
        enabled = on
        Task {
            do { try await state.api.send("PATCH", "/api/account/server-alerts", body: ["emailEnabled": on]); error = nil }
            catch { enabled = before; self.error = error.localizedDescription }
        }
    }
}

// ---------- Konto löschen ----------

private struct DeletionCard: View {
    @EnvironmentObject var state: AppState
    @State private var scheduledFor: String?
    @State private var graceDays: Int?
    @State private var loaded = false
    @State private var showForm = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Konto löschen").font(.headline).foregroundStyle(Tokens.text)
                if let scheduledFor {
                    Text("Die Löschung ist für \(Self.date(scheduledFor)) vorgemerkt. Bis dahin kannst du sie abbrechen.")
                        .font(.subheadline).foregroundStyle(Tokens.warn)
                    PillButton(title: "Löschung abbrechen", symbol: "arrow.uturn.backward", busy: busy) { cancel() }
                } else {
                    Text("Beantragt die Löschung deines Kontos\(graceDays.map { " nach \($0) Tagen Wartezeit" } ?? ""). Solange Produkte aktiv sind, ist das nicht möglich.")
                        .font(.footnote).foregroundStyle(Tokens.dim)
                    PillButton(title: "Konto löschen", symbol: "trash.fill", tint: Tokens.bad) { showForm = true }
                        .disabled(!loaded)
                }
                ErrorLine(text: error)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showForm) {
            DeletionForm { await load() }
        }
    }

    private func load() async {
        guard let data = try? await state.api.send("GET", "/api/account/deletion") else { return }
        let o = json(data)
        scheduledFor = o["scheduledFor"] as? String
        graceDays = o["graceDays"] as? Int
        loaded = true
    }

    private func cancel() {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do { try await state.api.send("DELETE", "/api/account/deletion"); await load() }
            catch { self.error = error.localizedDescription }
        }
    }

    static func date(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d else { return String(iso.prefix(10)) }
        return d.formatted(date: .long, time: .omitted)
    }
}

private struct DeletionForm: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var password = ""
    @State private var code = ""
    @State private var confirm = ""
    @State private var totpEnabled = false
    @State private var busy = false
    @State private var error: String?
    @State private var ask = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Konto löschen").font(.headline).foregroundStyle(Tokens.text)
                            Text("Tippe zur Bestätigung LÖSCHEN und gib dein Passwort ein.")
                                .font(.subheadline).foregroundStyle(Tokens.dim)
                            InputField(title: "LÖSCHEN", text: $confirm)
                            InputField(title: "Passwort", text: $password, secure: true)
                            if totpEnabled { InputField(title: "Bestätigungscode (2FA)", text: $code, code: true) }
                            ErrorLine(text: error)
                            PillButton(title: "Löschung beantragen", symbol: "trash.fill", tint: Tokens.bad, busy: busy) { ask = true }
                                .disabled(confirm.uppercased() != "LÖSCHEN" || password.isEmpty)
                        }
                    }
                }
                .padding(Tokens.pad)
            }
            .background(Tokens.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .confirmationDialog("Konto wirklich löschen?", isPresented: $ask, titleVisibility: .visible) {
                Button("Löschung beantragen", role: .destructive) { submit() }
                Button("Abbrechen", role: .cancel) {}
            } message: { Text("Das Konto wird nach der Wartezeit endgültig gelöscht.") }
            .task {
                if let data = try? await state.api.send("GET", "/api/account/email-change") {
                    totpEnabled = json(data)["totpEnabled"] as? Bool ?? false
                }
            }
        }
    }

    private func submit() {
        busy = true; error = nil
        var body: [String: Any] = ["password": password, "confirm": "LÖSCHEN"]
        if totpEnabled { body["code"] = code }
        Task {
            defer { busy = false }
            do {
                try await state.api.send("POST", "/api/account/deletion", body: body)
                await done()
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
}
