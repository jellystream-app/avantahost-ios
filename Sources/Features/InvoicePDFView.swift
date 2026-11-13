import SwiftUI
import PDFKit

struct InvoicePDFView: View {
    @EnvironmentObject var state: AppState
    let invoice: Invoice?
    @State private var fileURL: URL?
    @State private var error: String?

    var body: some View {
        Group {
            if let fileURL {
                PDFKitView(url: fileURL)
            } else if let error {
                VStack { ErrorLine(text: error); Spacer() }.padding(Tokens.pad)
            } else {
                ProgressView()
            }
        }
        .background(Tokens.bg)
        .navigationTitle(invoice?.number ?? "Rechnung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let fileURL { ToolbarItem(placement: .topBarTrailing) { ShareLink(item: fileURL) } }
        }
        .task { await load() }
    }

    private func load() async {
        guard let invoice else { error = "Rechnung nicht gefunden."; return }
        do {
            let data = try await state.api.send("GET", "/api/invoices/\(invoice.id)?format=pdf&inline=1")
            guard data.starts(with: Data("%PDF".utf8)) else { error = "Die Antwort ist kein PDF."; return }
            let name = invoice.number.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            try data.write(to: url, options: .atomic)
            fileURL = url
        } catch { self.error = error.localizedDescription }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.backgroundColor = UIColor(Tokens.bg)
        v.document = PDFDocument(url: url)
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {}
}
