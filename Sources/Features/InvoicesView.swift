import SwiftUI

struct InvoicesView: View {
    @EnvironmentObject var state: AppState
    @State private var items: [Invoice] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @StateObject private var labels = InvoiceLabels()
    @State private var editing: Invoice?
    @State private var draft = ""

    private var filtered: [Invoice] {
        let words = fold(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return items }
        return items.filter { inv in
            let hay = fold(inv.searchText(label: labels.label(for: inv.id)))
            return words.allSatisfy { hay.contains($0) }
        }
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    ScreenTitle(text: "Rechnungen")
                    NavigationLink(value: "wallet") {
                        Card {
                            HStack(spacing: 12) {
                                IconTile(symbol: "creditcard.fill")
                                Text("Guthaben").font(.headline).foregroundStyle(Tokens.text)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Tokens.dim)
                            }
                        }
                    }.buttonStyle(.plain)
                    if !items.isEmpty { searchField }
                    ErrorLine(text: error)
                    if items.isEmpty && !loading && error == nil {
                        Card { Text("Keine Rechnungen.").foregroundStyle(Tokens.dim) }
                    } else if filtered.isEmpty && !items.isEmpty {
                        Card { Text("Keine Treffer.").foregroundStyle(Tokens.dim) }
                    }
                    ForEach(filtered) { inv in
                        NavigationLink(value: inv.id) { row(inv) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    draft = labels.label(for: inv.id) ?? ""
                                    editing = inv
                                } label: { Label("Label bearbeiten", systemImage: "tag") }
                                if labels.label(for: inv.id) != nil {
                                    Button(role: .destructive) { labels.set("", for: inv.id) } label: {
                                        Label("Label entfernen", systemImage: "tag.slash")
                                    }
                                }
                            }
                    }
                }
                .padding(Tokens.pad)
            }
            .background(Tokens.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { id in
                InvoicePDFView(invoice: items.first { $0.id == id })
            }
            .navigationDestination(for: String.self) { _ in WalletView() }
            .refreshable { await load() }
            .alert("Label", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("z. B. Minecraft Server", text: $draft)
                Button("Speichern") { if let e = editing { labels.set(draft, for: e.id) }; editing = nil }
                Button("Abbrechen", role: .cancel) { editing = nil }
            } message: {
                Text(editing?.number ?? "")
            }
        }
        .task { await load() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Tokens.dim)
            TextField("Name, Nummer, Betrag …", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Tokens.dim) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Tokens.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ inv: Invoice) -> some View {
        Card {
            HStack(spacing: 12) {
                IconTile(symbol: "doc.text.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text(labels.label(for: inv.id) ?? inv.number).font(.headline).foregroundStyle(Tokens.text).lineLimit(1)
                    Text(labels.label(for: inv.id) != nil ? "\(inv.number) · \(sub(inv))" : sub(inv))
                        .font(.subheadline).foregroundStyle(Tokens.dim).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(inv.amount).font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.text)
                    Text(inv.statusLabel).font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(color(inv).opacity(0.14), in: Capsule())
                        .foregroundStyle(color(inv))
                }
            }
        }
    }

    private func sub(_ inv: Invoice) -> String {
        let date = inv.issuedAt.map { $0.formatted(date: .abbreviated, time: .omitted) }
        return [date, inv.title].compactMap { $0 }.joined(separator: " · ")
    }

    private func color(_ inv: Invoice) -> Color {
        inv.paid || inv.credit ? Tokens.ok : Tokens.warn
    }

    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            let r: InvoiceListResponse = try await state.api.get("/api/invoices")
            items = r.invoices
        } catch { self.error = error.localizedDescription }
    }
}
