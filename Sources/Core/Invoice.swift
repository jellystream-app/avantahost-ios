import Foundation

struct Invoice: Identifiable, Decodable {
    let id: Int
    let number: String
    let totalCents: Int
    let status: String
    let issuedAt: Date?
    let paid: Bool
    let credit: Bool
    let title: String?

    enum K: String, CodingKey { case id, invoice_number, total_cents, status, issued_at, paid_at, kind, plan_name, line_description }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flex(.id)?.int ?? 0
        number = c.str(.invoice_number) ?? "Rechnung"
        totalCents = c.flex(.total_cents)?.int ?? 0
        status = c.str(.status) ?? ""
        issuedAt = c.str(.issued_at).flatMap(Invoice.parse)
        paid = c.str(.paid_at) != nil || status == "paid"
        credit = c.str(.kind) == "credit_note"
        title = c.str(.plan_name) ?? c.str(.line_description)
    }

    var amount: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: NSNumber(value: Double(totalCents) / 100)) ?? "\(totalCents) ct"
    }

    var statusLabel: String {
        if credit { return "Gutschrift" }
        if paid { return "Bezahlt" }
        switch status {
        case "issued": return "Offen"
        case "void", "cancelled": return "Storniert"
        default: return status.isEmpty ? "Offen" : status.capitalized
        }
    }

    private static func parse(_ s: String) -> Date? {
        let a = ISO8601DateFormatter()
        a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: s) { return d }
        a.formatOptions = [.withInternetDateTime]
        return a.date(from: s)
    }
}

struct InvoiceListResponse: Decodable {
    let invoices: [Invoice]
}

/// Eigene Bezeichnungen für Rechnungen, nur auf diesem Gerät gespeichert.
@MainActor
final class InvoiceLabels: ObservableObject {
    private static let key = "invoice_labels"
    @Published private(set) var labels: [Int: String]

    init() {
        let raw = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        labels = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
    }

    func label(for id: Int) -> String? { labels[id] }

    func set(_ text: String, for id: Int) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { labels.removeValue(forKey: id) } else { labels[id] = String(t.prefix(60)) }
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: labels.map { (String($0.key), $0.value) }),
                                  forKey: Self.key)
    }
}

extension Invoice {
    /// Durchsuchbarer Text: Nummer, Titel, eigenes Label, Betrag, Status und Datum.
    func searchText(label: String?) -> String {
        let date = issuedAt.map { $0.formatted(date: .numeric, time: .omitted) + " " + $0.formatted(date: .long, time: .omitted) }
        return [number, title, label, amount, statusLabel, date].compactMap { $0 }.joined(separator: " ")
    }
}
