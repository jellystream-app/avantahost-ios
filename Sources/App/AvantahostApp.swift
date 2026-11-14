import SwiftUI

@main
struct AvantahostApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var lock = FaceLock()
    @StateObject private var platform = PlatformStatus()
    @Environment(\.scenePhase) private var scene

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if lock.locked { LockView() }
            }
                .environmentObject(state)
                .environmentObject(lock)
                .environmentObject(platform)
                .onChange(of: scene) { _, p in
                    if p == .background { lock.lockIfNeeded() }
                    if p == .active, lock.locked { Task { await lock.autoUnlock() } }
                    if p == .active { Task { await platform.refresh(api: state.api) } }
                }
                .tint(Tokens.accent)
                .task { await state.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        switch state.phase {
        case .loading:
            ZStack { Tokens.bg.ignoresSafeArea(); ProgressView() }
        case .loggedOut:
            LoginView()
        case .unverified(let user):
            VerifyEmailView(user: user)
        case .ready:
            MainTabs()
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var quick = QuickActions.shared
    @State private var result: String?

    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Übersicht", systemImage: "square.grid.2x2.fill") }
            InvoicesView().tabItem { Label("Rechnungen", systemImage: "doc.text.fill") }
            TicketsView().tabItem { Label("Tickets", systemImage: "bubble.left.and.bubble.right.fill") }
            AccountView().tabItem { Label("Konto", systemImage: "person.crop.circle.fill") }
        }
        .confirmationDialog(quick.pending?.name ?? "", isPresented: Binding(
            get: { quick.pending != nil }, set: { if !$0 { quick.pending = nil } }),
            titleVisibility: .visible, presenting: quick.pending) { p in
            Button("Starten") { run(p, "start", done: "Start gesendet.") }
            Button("Neustart") { run(p, "restart", done: "Neustart gesendet.") }
            Button("Stoppen", role: .destructive) { run(p, "stop", done: "Stopp gesendet.") }
            Button("Abbrechen", role: .cancel) {}
        }
        .alert("Server", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(result ?? "") }
    }

    private func run(_ p: PendingPower, _ action: String, done: String) {
        let service = Service(id: p.serverId, name: p.name, plan: nil, status: .unknown, provider: p.provider, shared: false)
        Task {
            do {
                try await ServerDetailLoader.power(service, action, api: state.api)
                result = "\(p.name): \(done)"
            } catch { result = "\(p.name): \(error.localizedDescription)" }
        }
    }
}

struct LockView: View {
    @EnvironmentObject var lock: FaceLock
    var body: some View {
        ZStack {
            Tokens.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 36)).foregroundStyle(Tokens.accent)
                ErrorLine(text: lock.message)
                PrimaryButton(title: "Entsperren") { Task { await lock.unlock() } }
            }.padding(Tokens.pad)
        }
        .task { await lock.autoUnlock() }
    }
}
