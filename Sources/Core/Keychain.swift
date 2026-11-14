import Foundation
import Security

enum Keychain {
    private static let service = "de.avantahost.app"

    static func read(_ key: String) -> String? {
        var q = base(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String) {
        delete(key)
        var q = base(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    /// Kopie in der App Group, damit das Widget die Sitzung lesen kann. Ohne Berechtigung passiert nichts.
    static func writeShared(_ key: String, _ value: String) {
        guard let group = WidgetShare.groupId else { return }
        var q = base(key)
        q[kSecAttrAccessGroup as String] = group
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func deleteShared(_ key: String) {
        guard let group = WidgetShare.groupId else { return }
        var q = base(key)
        q[kSecAttrAccessGroup as String] = group
        SecItemDelete(q as CFDictionary)
    }

    static func delete(_ key: String) {
        SecItemDelete(base(key) as CFDictionary)
    }

    private static func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }
}
