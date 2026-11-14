import Foundation
import LocalAuthentication

/// Lokale Sperre per Face ID / Touch ID. Der Schalter liegt in UserDefaults.
@MainActor
final class FaceLock: ObservableObject {
    static let key = "faceLockEnabled"
    @Published var locked: Bool
    @Published var isOn: Bool
    @Published var message: String?

    private var busy = false
    // Systemdialog schickt die Szene inactive -> active; ohne Flag würde jeder Abbruch neu fragen.
    private var autoPrompt: Bool

    init() {
        let on = UserDefaults.standard.bool(forKey: Self.key)
        locked = on
        isOn = on
        autoPrompt = on
    }

    var enabled: Bool { isOn }

    /// Name der verfügbaren Biometrie für Beschriftungen.
    static var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Face ID"
        }
    }

    func lockIfNeeded() {
        guard isOn else { return }
        locked = true
        autoPrompt = true
    }

    /// Automatischer Versuch nach dem Sperren; höchstens einmal je Sperre.
    func autoUnlock() async {
        guard locked, autoPrompt else { return }
        autoPrompt = false
        await unlock()
    }

    func unlock() async {
        guard locked, !busy else { return }
        busy = true
        defer { busy = false }
        message = nil
        let reason = "\(Self.biometryName) zum Entsperren von Avantahost"
        switch await evaluate(.deviceOwnerAuthenticationWithBiometrics, reason: reason) {
        case .success:
            locked = false
        case .failure(let e):
            if Self.needsPasscode(e) {
                if case .success = await evaluate(.deviceOwnerAuthentication, reason: "Avantahost mit dem Gerätecode entsperren") {
                    locked = false
                }
            } else if !Self.isCancel(e) {
                message = Self.text(e)
            }
        }
    }

    /// Schalter ein/aus. Gibt eine Fehlermeldung zurück, nil bei Erfolg oder Abbruch.
    func setEnabled(_ on: Bool) async -> String? {
        guard !busy else { return nil }
        busy = true
        defer { busy = false }
        let ctx = LAContext()
        var err: NSError?
        if on, !ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
            return Self.text(err ?? NSError(domain: LAError.errorDomain, code: LAError.biometryNotAvailable.rawValue))
        }
        let reason = on ? "\(Self.biometryName) für die Sperre bestätigen" : "Sperre mit \(Self.biometryName) aufheben"
        switch await evaluate(.deviceOwnerAuthenticationWithBiometrics, reason: reason) {
        case .success:
            UserDefaults.standard.set(on, forKey: Self.key)
            isOn = on
            return nil
        case .failure(let e):
            if Self.needsPasscode(e), !on,
               case .success = await evaluate(.deviceOwnerAuthentication, reason: "Sperre mit dem Gerätecode aufheben") {
                UserDefaults.standard.set(false, forKey: Self.key)
                isOn = false
                return nil
            }
            return Self.isCancel(e) ? nil : Self.text(e)
        }
    }

    private func evaluate(_ policy: LAPolicy, reason: String) async -> Result<Void, NSError> {
        let ctx = LAContext()
        if policy == .deviceOwnerAuthenticationWithBiometrics { ctx.localizedFallbackTitle = "" }
        var err: NSError?
        guard ctx.canEvaluatePolicy(policy, error: &err) else {
            return .failure(err ?? NSError(domain: LAError.errorDomain, code: LAError.biometryNotAvailable.rawValue))
        }
        do {
            let ok = try await ctx.evaluatePolicy(policy, localizedReason: reason)
            return ok ? .success(()) : .failure(NSError(domain: LAError.errorDomain, code: LAError.authenticationFailed.rawValue))
        } catch {
            return .failure(error as NSError)
        }
    }

    // Ohne Biometrie (gesperrt, entfernt) wäre die App sonst dauerhaft zu.
    private static func needsPasscode(_ e: NSError) -> Bool {
        guard e.domain == LAError.errorDomain else { return false }
        switch LAError.Code(rawValue: e.code) {
        case .biometryLockout, .biometryNotEnrolled, .biometryNotAvailable: return true
        default: return false
        }
    }

    private static func isCancel(_ e: NSError) -> Bool {
        guard e.domain == LAError.errorDomain else { return false }
        switch LAError.Code(rawValue: e.code) {
        case .userCancel, .systemCancel, .appCancel: return true
        default: return false
        }
    }

    private static func text(_ e: NSError) -> String {
        let name = biometryName
        guard e.domain == LAError.errorDomain else { return "Entsperren fehlgeschlagen." }
        switch LAError.Code(rawValue: e.code) {
        case .biometryNotEnrolled: return "\(name) ist auf diesem Gerät nicht eingerichtet. Richte es zuerst in den iOS-Einstellungen ein."
        case .biometryNotAvailable: return "\(name) ist auf diesem Gerät nicht verfügbar oder für Avantahost nicht erlaubt."
        case .biometryLockout: return "\(name) ist gesperrt. Entsperre es mit dem Gerätecode."
        case .authenticationFailed: return "\(name) wurde nicht erkannt."
        default: return "Entsperren fehlgeschlagen."
        }
    }
}
