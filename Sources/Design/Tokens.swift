import SwiftUI

/// Farben der App. Der dunkle Modus folgt den Farben der Website.
enum Tokens {
    static let bg = dyn(0xF2F3F7, 0x05070A)
    static let card = dyn(0xFFFFFF, 0x0D111B)
    static let line = dyn(0xE5E7EB, 0x191B1E)
    static let text = dyn(0x111827, 0xF1F5F9)
    static let dim = dyn(0x6B7280, 0x64748B)
    static let accent = Color(hex: 0xA069E2)
    /// Text auf dem Akzent: dunkel hat mehr Kontrast als weiß.
    static let onAccent = Color(hex: 0x05070A)
    static let accentSoft = dyn(0xEEE4FA, 0x241B35)
    static let ok = Color(hex: 0x22A55B)
    static let warn = Color(hex: 0xE8890C)
    static let bad = Color(hex: 0xD92D20)

    static let cardRadius: CGFloat = 18
    static let tileRadius: CGFloat = 12
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12
    static let barHeight: CGFloat = 6

    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}
