import Foundation

/// Zahl oder String aus JSON (Postgres liefert bigint/numeric oft als String).
struct Flex: Decodable {
    let string: String
    var int: Int? { Int(string) ?? Double(string).map { Int($0) } }
    var double: Double? { Double(string) }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { string = s }
        else if let i = try? c.decode(Int.self) { string = String(i) }
        else if let d = try? c.decode(Double.self) { string = String(d) }
        else if let b = try? c.decode(Bool.self) { string = b ? "1" : "0" }
        else { string = "" }
    }
}

extension KeyedDecodingContainer {
    func flex(_ key: Key) -> Flex? { try? decodeIfPresent(Flex.self, forKey: key) }
    func str(_ key: Key) -> String? {
        guard let f = flex(key), !f.string.isEmpty else { return nil }
        return f.string
    }
}
