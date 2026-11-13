import SwiftUI

struct TicketsView: View {
    @EnvironmentObject var state: AppState
    @State private var tickets: [Ticket] = []
    @State private var loading = false
    @State private var error: String?
    @State private var composing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    HStack {
                        ScreenTitle(text: "Tickets")
                        Button { composing = true } label: {
                            Image(systemName: "plus").font(.headline).foregroundStyle(Tokens.onAccent)
                                .frame(width: 40, height: 40).background(Tokens.accent, in: Circle())
                        }
                    }
                    ErrorLine(text: error)
                    if tickets.isEmpty && !loading && error == nil {
                        Card { Text("Keine Tickets.").foregroundStyle(Tokens.dim) }
                    }
                    ForEach(tickets) { t in
                        NavigationLink(value: t.id) { row(t) }.buttonStyle(.plain)
                    }
                }
                .padding(Tokens.pad)
            }
            .background(Tokens.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { TicketDetailView(ticketId: $0) }
            .refreshable { await load() }
            .sheet(isPresented: $composing, onDismiss: { Task { await load() } }) { NewTicketView() }
        }
        .task { await load() }
    }

    private func row(_ t: Ticket) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t.subject).font(.headline).foregroundStyle(Tokens.text).lineLimit(1)
                    Spacer()
                    Text(t.statusLabel).font(.caption.weight(.semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Tokens.accentSoft, in: Capsule()).foregroundStyle(Tokens.accent)
                }
                if let m = t.lastMessage {
                    Text(m).font(.subheadline).foregroundStyle(Tokens.dim).lineLimit(2)
                }
                if let d = t.updatedAt {
                    Text(d.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Tokens.dim)
                }
            }
        }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r: TicketListResponse = try await state.api.get("/api/tickets")
            tickets = r.tickets; error = nil
        } catch ApiError.unauthorized { await state.refreshUser() }
        catch { self.error = error.localizedDescription }
    }
}

struct TicketDetailView: View {
    @EnvironmentObject var state: AppState
    let ticketId: Int
    @State private var ticket: Ticket?
    @State private var messages: [TicketMessage] = []
    @State private var reply = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    ErrorLine(text: error)
                    ForEach(messages) { m in
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(m.isStaff ? "Avantahost Support" : (m.author ?? "Du"))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(m.isStaff ? Tokens.accent : Tokens.dim)
                                    Spacer()
                                    if let d = m.createdAt {
                                        Text(d.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(Tokens.dim)
                                    }
                                }
                                Text(m.text).foregroundStyle(Tokens.text)
                            }
                        }
                    }
                }
                .padding(Tokens.pad)
            }
            if ticket?.status != "closed" && ticket?.status != "archived" {
                HStack(spacing: 8) {
                    TextField("Antwort schreiben", text: $reply, axis: .vertical)
                        .lineLimit(1...4).padding(12)
                        .background(Tokens.card, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").font(.headline).foregroundStyle(Tokens.onAccent)
                            .frame(width: 40, height: 40).background(Tokens.accent, in: Circle())
                    }
                    .disabled(busy || reply.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
                .padding(Tokens.pad)
            }
        }
        .background(Tokens.bg)
        .navigationTitle(ticket?.subject ?? "Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            let r: TicketDetailResponse = try await state.api.get("/api/tickets/\(ticketId)")
            ticket = r.ticket; messages = r.messages; error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func send() async {
        busy = true; defer { busy = false }
        do {
            try await state.api.send("POST", "/api/tickets/\(ticketId)/messages",
                                     body: ["message": String(reply.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1500))])
            reply = ""
            await load()
        } catch { self.error = error.localizedDescription }
    }
}

struct NewTicketView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    static let maxChars = 1500
    @State private var subject = ""
    @State private var message = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.gap) {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Betreff", text: $subject)
                                .padding(12).background(Tokens.bg, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
                            TextField("Beschreibe dein Anliegen", text: $message, axis: .vertical)
                                .lineLimit(6...12)
                                .padding(12).background(Tokens.bg, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
                                .onChange(of: message) { _, v in if v.count > Self.maxChars { message = String(v.prefix(Self.maxChars)) } }
                            Text("\(message.count)/\(Self.maxChars) Zeichen")
                                .font(.caption).foregroundStyle(Tokens.dim)
                        }
                    }
                    ErrorLine(text: error)
                    PrimaryButton(title: "Ticket senden", busy: busy) { Task { await submit() } }
                        .disabled(subject.trimmingCharacters(in: .whitespaces).count < 4 || message.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                }
                .padding(Tokens.pad)
            }
            .background(Tokens.bg)
            .navigationTitle("Neues Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }

    private func submit() async {
        busy = true; error = nil; defer { busy = false }
        do {
            try await state.api.send("POST", "/api/tickets", body: [
                "subject": subject.trimmingCharacters(in: .whitespaces),
                "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
                "category": "general", "priority": "normal",
            ])
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
