import Foundation
import LocalAuthentication

/// Lokale Sperre mit Face ID / Code. Schalter liegt in UserDefaults.
@MainActor
final class FaceLock: ObservableObject {
    static let key = "faceLockEnabled"
    @Published var locked: Bool

    init() { locked = UserDefaults.standard.bool(forKey: Self.key) }

    var enabled: Bool { UserDefaults.standard.bool(forKey: Self.key) }

    func lockIfNeeded() { if enabled { locked = true } }

    func unlock() async {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        if let ok = try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Avantahost entsperren"), ok {
            locked = false
        }
    }

    func setEnabled(_ on: Bool) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return false }
        let ok = (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sperre bestätigen")) ?? false
        if ok { UserDefaults.standard.set(on, forKey: Self.key) }
        return ok
    }
}
