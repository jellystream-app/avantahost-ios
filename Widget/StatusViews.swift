import SwiftUI
import WidgetKit

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .signedOut:
            Notice(text: "Nicht angemeldet", hint: "App öffnen")
        case .data(let snap, let locked, let offline):
            switch family {
            case .accessoryCircular: Circular(snap: snap)
            case .accessoryRectangular: Rectangular(snap: snap, offline: offline)
            case .systemMedium: Medium(snap: snap, locked: locked, offline: offline)
            default: Small(snap: snap, offline: offline)
            }
        }
    }
}

private struct Notice: View {
    let text: String
    let hint: String
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text).font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text(hint).font(.caption).foregroundStyle(family.isAccessory ? .secondary : WP.dim)
        }
        .foregroundStyle(family.isAccessory ? .primary : WP.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private extension WidgetFamily {
    var isAccessory: Bool { self == .accessoryCircular || self == .accessoryRectangular }
}

private struct Stamp: View {
    let date: Date
    let offline: Bool

    var body: some View {
        Text(offline ? "Offline, Stand \(date.formatted(date: .omitted, time: .shortened))"
                     : "Stand \(date.formatted(date: .omitted, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(offline ? Tokens.warn : WP.dim)
            .lineLimit(1)
    }
}

private struct Count: View {
    let snap: WidgetSnapshot

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(snap.online)").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(WP.text)
            Text("/ \(snap.total)").font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(WP.dim)
        }
    }
}

private struct Small: View {
    let snap: WidgetSnapshot
    let offline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Server").font(.caption.weight(.semibold)).foregroundStyle(WP.accent)
            Spacer(minLength: 0)
            if snap.total == 0 {
                Text("Keine Server").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(WP.text)
            } else {
                Count(snap: snap)
                Text("online").font(.caption).foregroundStyle(WP.dim)
            }
            Spacer(minLength: 0)
            Stamp(date: snap.updated, offline: offline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct Medium: View {
    let snap: WidgetSnapshot
    let locked: Bool
    let offline: Bool

    /// Probleme zuerst, damit offline Server nicht abgeschnitten werden.
    private var shown: [WidgetServer] {
        Array(snap.servers.sorted { ($0.status == .running ? 1 : 0) < ($1.status == .running ? 1 : 0) }.prefix(3))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Server").font(.caption.weight(.semibold)).foregroundStyle(WP.accent)
                Spacer(minLength: 0)
                if snap.total > 0 {
                    Count(snap: snap)
                    Text("online").font(.caption).foregroundStyle(WP.dim)
                }
                Spacer(minLength: 0)
                Stamp(date: snap.updated, offline: offline)
            }
            VStack(alignment: .leading, spacing: 6) {
                if snap.total == 0 {
                    Text("Keine Server").font(.subheadline).foregroundStyle(WP.dim)
                } else if locked {
                    ForEach(Array(Dictionary(grouping: snap.servers, by: { $0.status.label }).sorted { $0.key < $1.key }), id: \.key) { g in
                        Row(title: "\(g.value.count)x \(g.key)", status: g.value[0].status)
                    }
                } else {
                    ForEach(shown, id: \.self) { s in Row(title: s.name, status: s.status) }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(WP.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct Row: View {
    let title: String
    let status: ServerStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(status.color).frame(width: 7, height: 7)
            Text(title).font(.caption.weight(.medium)).foregroundStyle(WP.text).lineLimit(1)
            Spacer(minLength: 0)
            Text(status.label).font(.caption2).foregroundStyle(WP.dim).lineLimit(1)
        }
    }
}

private struct Circular: View {
    let snap: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(snap.online)/\(snap.total)").font(.system(.title3, design: .rounded).weight(.bold))
                Text("online").font(.system(size: 9))
            }
        }
    }
}

private struct Rectangular: View {
    let snap: WidgetSnapshot
    let offline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Avantahost").font(.caption.weight(.semibold))
            Text(snap.total == 0 ? "Keine Server" : "\(snap.online) von \(snap.total) online")
                .font(.system(.headline, design: .rounded))
            Text(offline ? "Offline" : "Stand \(snap.updated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
