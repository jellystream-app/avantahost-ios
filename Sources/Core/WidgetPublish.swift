import WidgetKit

/// Nur in der App: Stand an das Widget geben und es neu zeichnen lassen.
extension WidgetShare {
    static func publish(_ services: [Service]) {
        save(services)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func reset() {
        clear()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
