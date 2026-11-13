import Foundation

/// Liest ein Cookie aus Set-Cookie-Headern. Apple fasst mehrere Set-Cookie-Header
/// mit ", " zusammen; Expires=Fri, 13 Nov ... enthaelt ebenfalls ein Komma.
enum SessionCookie {
    /// Alle Teile des (evtl. zusammengefassten) Headers, ein Cookie je Eintrag.
    static func split(_ raw: String) -> [String] {
        var parts: [String] = [], cur = ""
        let chars = Array(raw)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == ",", startsNewCookie(chars, i + 1) {
                parts.append(cur); cur = ""
            } else { cur.append(c) }
            i += 1
        }
        parts.append(cur)
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Nach dem Komma folgt "name=" (kein Datum wie " 13 Nov 2026").
    private static func startsNewCookie(_ s: [Character], _ from: Int) -> Bool {
        var j = from
        while j < s.count, s[j] == " " { j += 1 }
        let start = j
        while j < s.count, s[j] != "=", s[j] != ";", s[j] != ",", s[j] != " " { j += 1 }
        return j > start && j < s.count && s[j] == "="
    }

    /// Wert des Cookies `name`, nur wenn es am Anfang eines Cookies steht.
    static func value(named name: String, in headers: [String]) -> String? {
        for h in headers {
            for part in split(h) {
                guard let eq = part.firstIndex(of: "=") else { continue }
                let n = part[..<eq].trimmingCharacters(in: .whitespaces)
                guard n == name else { continue }
                var v = String(part[part.index(after: eq)...].prefix { $0 != ";" })
                v = v.trimmingCharacters(in: .whitespaces)
                if v.count >= 2, v.hasPrefix("\""), v.hasSuffix("\"") { v = String(v.dropFirst().dropLast()) }
                if !v.isEmpty { return v }
            }
        }
        return nil
    }

    /// Alle Set-Cookie-Werte, unabhaengig von der Schreibweise des Header-Namens.
    static func headerValues(_ resp: HTTPURLResponse) -> [String] {
        resp.allHeaderFields.compactMap { k, v -> String? in
            guard let k = k as? String, k.lowercased() == "set-cookie" else { return nil }
            return v as? String
        }
    }

    /// Nur Namen der Antwort-Header, keine Werte.
    static func headerNames(_ resp: HTTPURLResponse) -> String {
        resp.allHeaderFields.keys.compactMap { ($0 as? String)?.lowercased() }.sorted().joined(separator: ", ")
    }
}
