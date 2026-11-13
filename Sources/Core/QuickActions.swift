import UIKit
import SwiftUI
import UserNotifications

/// Server, für den eine Quick Action (App-Icon gedrückt halten) ausgelöst wurde.
struct PendingPower: Identifiable {
    let id = UUID()
    let serverId: Int
    let provider: Provider
    let name: String
}

@MainActor
final class QuickActions: ObservableObject {
    static let shared = QuickActions()
    private static let type = "de.avantahost.server"

    @Published var pending: PendingPower?

    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == Self.type, let info = item.userInfo,
              let idString = info["id"] as? String, let id = Int(idString),
              let provider = info["provider"] as? String else { return false }
        pending = PendingPower(serverId: id, provider: provider == "kvm" ? .kvm : .game, name: item.localizedTitle)
        return true
    }

    /// Bis zu vier Server als Kurzbefehle am App-Icon.
    func update(_ services: [Service]) {
        UIApplication.shared.shortcutItems = services.prefix(4).map { s in
            UIApplicationShortcutItem(
                type: Self.type,
                localizedTitle: s.name,
                localizedSubtitle: "Start · Neustart · Stopp",
                icon: UIApplicationShortcutIcon(systemImageName: s.provider == .kvm ? "server.rack" : "gamecontroller.fill"),
                userInfo: ["id": String(s.id) as NSString,
                           "provider": (s.provider == .kvm ? "kvm" : "game") as NSString]
            )
        }
    }

    func clear() {
        UIApplication.shared.shortcutItems = []
        pending = nil
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Auch bei geöffneter App als Banner anzeigen.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Kaltstart über eine Quick Action
        if let item = options.shortcutItem { Task { @MainActor in QuickActions.shared.handle(item) } }
        let cfg = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        cfg.delegateClass = SceneDelegate.self
        return cfg
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // App läuft bereits im Hintergrund
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in completionHandler(QuickActions.shared.handle(shortcutItem)) }
    }
}
