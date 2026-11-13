import SwiftUI

struct AccountView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack { content }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Tokens.gap) {
                ScreenTitle(text: "Konto")
                if case .ready(let u) = state.phase {
                    Card {
                        HStack(spacing: 12) {
                            IconTile(symbol: "person.fill")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(u.displayName).font(.headline).foregroundStyle(Tokens.text)
                                Text(u.email).font(.subheadline).foregroundStyle(Tokens.dim)
                            }
                        }
                    }
                }
                NavigationLink { SecurityView() } label: {
                    Card {
                        HStack(spacing: 12) {
                            IconTile(symbol: "lock.shield.fill")
                            Text("Sicherheit").font(.headline).foregroundStyle(Tokens.text)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Tokens.dim)
                        }
                    }
                }.buttonStyle(.plain)
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rechtliches").font(.headline).foregroundStyle(Tokens.text)
                        ForEach([("Impressum", "impressum"), ("Datenschutz", "datenschutz"),
                                 ("AGB", "agb"), ("Widerrufsbelehrung", "widerruf")], id: \.1) { title, path in
                            Link(destination: URL(string: "https://avantahost.de/\(path)")!) {
                                HStack {
                                    Text(title).foregroundStyle(Tokens.text)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Tokens.dim)
                                }
                            }
                        }
                    }
                }
                PillButton(title: "Abmelden", symbol: "rectangle.portrait.and.arrow.right", tint: Tokens.bad) {
                    QuickActions.shared.clear()
                    Task { await state.logout() }
                }
                Text("Avantahost iOS 0.1").font(.caption).foregroundStyle(Tokens.dim).padding(.top, 8)
            }
            .padding(Tokens.pad)
        }
        .background(Tokens.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}
