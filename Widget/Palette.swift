import SwiftUI

/// Feste dunkle Farben: Widgets sollen unabhängig vom Systemmodus wie die App im Dunkeln aussehen.
enum WP {
    static let bg = Color(hex: 0x05070A)
    static let card = Color(hex: 0x0D111B)
    static let text = Color(hex: 0xF1F5F9)
    static let dim = Color(hex: 0x64748B)
    static let accent = Tokens.accent
}

extension WidgetServer {
    var status: ServerStatus { ServerStatus(state) }
}

extension WidgetSnapshot {
    var online: Int { servers.filter { $0.status == .running }.count }
    var total: Int { servers.count }
}
