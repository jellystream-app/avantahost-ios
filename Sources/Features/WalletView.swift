import SwiftUI
import SafariServices

struct WalletTransaction: Identifiable, Decodable {
    let id: Int
    let amountCents: Int
    let note: String?
    let createdAt: Date?

    enum K: String, CodingKey { case id, amount_cents, note, created_at }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flex(.id)?.int ?? 0
        amountCents = c.flex(.amount_cents)?.int ?? 0
        note = c.str(.note)
        createdAt = Ticket.date(c.str(.created_at))
    }
}

struct WalletResponse: Decodable {
    let balanceCents: Int
    enum K: String, CodingKey { case balanceCents }
    init(from d: Decoder) throws {
        balanceCents = try d.container(keyedBy: K.self).flex(.balanceCents)?.int ?? 0
    }
}

struct WalletTransactionsResponse: Decodable { let transactions: [WalletTransaction] }

func euro(_ cents: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "EUR"
    f.locale = Locale(identifier: "de_DE")
    return f.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(cents) ct"
}

@MainActor
final class WalletModel: ObservableObject {
    @Published var balanceCents: Int?
    @Published var transactions: [WalletTransaction] = []
    @Published var error: String?
    @Published var info: String?
    @Published var busy = false
    @Published var checkout: CheckoutLink?
    private var topupId: Int?

    struct CheckoutLink: Identifiable { let id = UUID(); let url: URL }

    func load(_ api: ApiClient) async {
        error = nil
        do {
            let w: WalletResponse = try await api.get("/api/wallet")
            balanceCents = w.balanceCents
        } catch { self.error = error.localizedDescription }
        if let t: WalletTransactionsResponse = try? await api.get("/api/wallet/transactions?limit=30") {
            transactions = t.transactions
        }
    }

    func startTopup(_ api: ApiClient, cents: Int) async {
        busy = true; error = nil; info = nil
        defer { busy = false }
        do {
            let data = try await api.send("POST", "/api/wallet/topup/mollie/checkout",
                                          body: ["amountCents": cents, "waiverConfirmed": true])
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard let s = obj?["checkoutUrl"] as? String, let url = URL(string: s), url.scheme == "https" else {
                error = "Keine Zahlungsseite erhalten."; return
            }
            topupId = (obj?["topupId"] as? Int) ?? Int("\(obj?["topupId"] ?? "")")
            checkout = CheckoutLink(url: url)
        } catch { self.error = error.localizedDescription }
    }

    /// Nach dem Schließen der Zahlungsseite: Zahlung bei Mollie prüfen und Guthaben neu laden.
    func verify(_ api: ApiClient) async {
        guard let id = topupId else { return }
        busy = true; defer { busy = false }
        do {
            let data = try await api.send("POST", "/api/wallet/topup/verify", body: ["topupId": id])
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if obj?["success"] as? Bool == true {
                info = "Guthaben aufgeladen."
                topupId = nil
            } else if obj?["pending"] as? Bool == true {
                info = "Die Zahlung wird noch verarbeitet. Zum Aktualisieren nach unten ziehen."
            } else {
                error = "Die Zahlung wurde nicht abgeschlossen."
                topupId = nil
            }
        } catch { self.error = error.localizedDescription }
        await load(api)
    }
}

struct WalletView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var model = WalletModel()
    @State private var selected = 1000
    @State private var custom = ""
    @State private var waiver = false

    private let presets = [500, 1000, 2500, 5000]

    private var amount: Int {
        if let v = Double(custom.replacingOccurrences(of: ",", with: ".")), v > 0 { return Int((v * 100).rounded()) }
        return selected
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.gap) {
                ScreenTitle(text: "Guthaben")
                Card {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktuelles Guthaben").font(.subheadline).foregroundStyle(Tokens.dim)
                        Text(model.balanceCents.map(euro) ?? "–")
                            .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Tokens.text)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                ErrorLine(text: model.error)
                if let i = model.info { Card { Text(i).font(.subheadline).foregroundStyle(Tokens.ok) } }
                topup
                if !model.transactions.isEmpty { history }
            }
            .padding(Tokens.pad)
        }
        .background(Tokens.bg)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(state.api) }
        .task { await model.load(state.api) }
        .sheet(item: $model.checkout, onDismiss: { Task { await model.verify(state.api) } }) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
    }

    private var topup: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aufladen").font(.headline).foregroundStyle(Tokens.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(presets, id: \.self) { c in
                        Button { selected = c; custom = "" } label: {
                            Text(euro(c).replacingOccurrences(of: ",00", with: ""))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(custom.isEmpty && selected == c ? Tokens.accent : Tokens.accentSoft, in: Capsule())
                                .foregroundStyle(custom.isEmpty && selected == c ? Tokens.onAccent : Tokens.text)
                        }.buttonStyle(.plain)
                    }
                }
                TextField("Anderer Betrag in €", text: $custom)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Tokens.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Toggle(isOn: $waiver) {
                    Text("Ich verlange ausdrücklich, dass die Aufladung bereits vor Ablauf der Widerrufsfrist ausgeführt wird. Bei einem Widerruf erhalte ich das noch nicht verbrauchte Guthaben zurück.")
                        .font(.footnote).foregroundStyle(Tokens.dim)
                }.tint(Tokens.accent)
                Link("Widerrufsbelehrung", destination: URL(string: "https://avantahost.de/widerruf")!)
                    .font(.footnote.weight(.semibold))
                PrimaryButton(title: "\(euro(amount)) aufladen", busy: model.busy) {
                    Task { await model.startTopup(state.api, cents: amount) }
                }
                .disabled(!waiver || amount < 100)
                .opacity(!waiver || amount < 100 ? 0.5 : 1)
            }
        }
    }

    private var history: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Letzte Buchungen").font(.headline).foregroundStyle(Tokens.text)
                ForEach(model.transactions) { t in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.note ?? "Buchung").font(.subheadline).foregroundStyle(Tokens.text).lineLimit(2)
                            if let d = t.createdAt {
                                Text(d.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(Tokens.dim)
                            }
                        }
                        Spacer()
                        Text((t.amountCents > 0 ? "+" : "") + euro(t.amountCents))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(t.amountCents >= 0 ? Tokens.ok : Tokens.text)
                    }
                }
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Tokens.accent)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
