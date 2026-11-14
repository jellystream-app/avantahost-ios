import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case loading, loggedOut, unverified(User), ready(User) }

    @Published var phase: Phase = .loading
    let api = ApiClient.shared

    func bootstrap() async {
        guard api.hasToken else { phase = .loggedOut; return }
        api.shareSession()
        await refreshUser()
    }

    func refreshUser() async {
        do {
            let me: MeResponse = try await api.get("/api/auth/me")
            guard let u = me.user else { api.clearSession(); phase = .loggedOut; return }
            phase = u.emailVerified ? .ready(u) : .unverified(u)
        } catch ApiError.unauthorized {
            api.clearSession(); phase = .loggedOut
        } catch {
            // Netzfehler: Session behalten, Login-Screen nur wenn kein Nutzer bekannt
            if case .loading = phase { phase = .loggedOut }
        }
    }

    func login(email: String, password: String, totp: String?) async throws {
        try await api.login(email: email, password: password, totp: totp)
        await refreshUser()
    }

    func logout() async {
        await api.logout()
        WidgetShare.reset()
        phase = .loggedOut
    }
}
