import SwiftUI

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var totp = ""
    @State private var needTotp = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Tokens.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image("Logo").resizable().scaledToFit().frame(width: 84, height: 84)
                        Text("Avantahost").font(.system(size: 30, weight: .bold)).foregroundStyle(Tokens.text)
                        Text("Melde dich mit deinem Kundenkonto an.").font(.subheadline).foregroundStyle(Tokens.dim)
                    }
                    .padding(.top, 60)

                    Card {
                        VStack(spacing: 14) {
                            field("E-Mail", text: $email, secure: false)
                            field("Passwort", text: $password, secure: true)
                            if needTotp {
                                field("2FA-Code oder Recovery-Code", text: $totp, secure: false)
                            }
                            ErrorLine(text: error)
                            PrimaryButton(title: "Anmelden", busy: busy) { Task { await submit() } }
                                .disabled(email.isEmpty || password.isEmpty)
                        }
                    }
                    Text("Build \(BuildInfo.sha)").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(Tokens.text).padding(.top, 8)
                }
                .padding(Tokens.pad)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure { SecureField(title, text: text) }
            else {
                TextField(title, text: text)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(title == "E-Mail" ? .emailAddress : .default)
            }
        }
        .padding(14)
        .background(Tokens.bg, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
        .foregroundStyle(Tokens.text)
    }

    private func submit() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await state.login(email: email.trimmingCharacters(in: .whitespaces), password: password,
                                  totp: needTotp ? totp : nil)
        } catch ApiError.totpRequired {
            needTotp = true
            error = totp.isEmpty ? "Bitte den Code aus deiner Authenticator-App eingeben." : "Code ungültig."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct VerifyEmailView: View {
    @EnvironmentObject var state: AppState
    let user: User
    @State private var info: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Tokens.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "envelope.badge")
                    .font(.system(size: 34, weight: .semibold)).foregroundStyle(Tokens.warn)
                    .frame(width: 72, height: 72)
                    .background(Tokens.warn.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("E-Mail bestätigen").font(.system(size: 26, weight: .bold)).foregroundStyle(Tokens.text)
                Text("Bitte bestätige \(user.email), um Dienste und Tickets zu nutzen. Den Link findest du in der Bestätigungsmail.")
                    .multilineTextAlignment(.center).foregroundStyle(Tokens.dim)
                ErrorLine(text: info)
                PillButton(title: "Mail erneut senden", symbol: "paperplane.fill", busy: busy) {
                    Task { await resend() }
                }
                PillButton(title: "Ich habe bestätigt – prüfen", symbol: "checkmark.circle.fill", tint: Tokens.ok) {
                    Task { await state.refreshUser() }
                }
                Button("Abmelden") { Task { await state.logout() } }
                    .font(.subheadline).foregroundStyle(Tokens.dim)
                Spacer()
            }
            .padding(Tokens.pad * 1.5)
        }
    }

    private func resend() async {
        busy = true; defer { busy = false }
        do { try await state.api.resendVerification(); info = "Mail wurde gesendet." }
        catch { info = error.localizedDescription }
    }
}
