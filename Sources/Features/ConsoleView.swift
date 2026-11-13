import SwiftUI

struct ConsoleView: View {
    @StateObject private var stream: ConsoleStream
    @State private var command = ""
    @State private var sending = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(serverId: Int, api: ApiClient) {
        _stream = StateObject(wrappedValue: ConsoleStream(serverId: serverId, api: api))
    }

    var body: some View {
        VStack(spacing: Tokens.gap) {
            output
            ErrorLine(text: error)
            input
        }
        .padding(Tokens.pad)
        .background(Tokens.bg)
        .navigationTitle("Konsole")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stream.start() }
        .onDisappear { stream.stop() }
    }

    private var output: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(stream.lines) { l in
                        Text(l.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(l.system ? Tokens.accent : Tokens.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(l.id)
                    }
                    if stream.lines.isEmpty { status }
                }
                .padding(14)
            }
            .background(Tokens.card, in: RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous))
            .onChange(of: stream.lines.last?.id) { id in
                if let id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
        .overlay(alignment: .top) { banner }
    }

    @ViewBuilder private var status: some View {
        switch stream.phase {
        case .connecting: ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        case .online: Text("Noch keine Ausgabe.").font(.footnote).foregroundStyle(Tokens.dim)
        case .failed: EmptyView()
        }
    }

    @ViewBuilder private var banner: some View {
        if case .failed(let m) = stream.phase {
            Text(m).font(.footnote.weight(.semibold)).foregroundStyle(Tokens.bad)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Tokens.card, in: Capsule()).padding(8)
        }
    }

    private var input: some View {
        HStack(spacing: 8) {
            TextField("Befehl", text: $command)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused).submitLabel(.send).onSubmit { Task { await send() } }
                .padding(.horizontal, 16).frame(height: 48)
                .background(Tokens.card, in: Capsule())
                .foregroundStyle(Tokens.text)
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up").font(.headline.weight(.bold))
                    .foregroundStyle(Tokens.onAccent)
                    .frame(width: 48, height: 48).background(Tokens.accent, in: Circle())
            }
            .disabled(sending || command.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func send() async {
        let c = command.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty, !sending else { return }
        sending = true; error = nil
        defer { sending = false }
        do { try await stream.send(c); command = "" }
        catch { self.error = error.localizedDescription }
    }
}
