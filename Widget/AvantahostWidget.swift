import SwiftUI
import WidgetKit

@main
struct AvantahostWidgets: WidgetBundle {
    var body: some Widget {
        ServerStatusWidget()
    }
}

struct ServerStatusWidget: Widget {
    let kind = "ServerStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(WP.bg, for: .widget)
        }
        .configurationDisplayName("Serverstatus")
        .description("Zeigt, wie viele deiner Server online sind.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
