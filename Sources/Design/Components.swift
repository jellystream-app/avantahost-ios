import SwiftUI

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(Tokens.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.card, in: RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct IconTile: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Tokens.accent)
            .frame(width: 44, height: 44)
            .background(Tokens.accentSoft, in: RoundedRectangle(cornerRadius: Tokens.tileRadius, style: .continuous))
    }
}

struct StatusBadge: View {
    let status: ServerStatus
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 7, height: 7)
            Text(status.label).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(status.color.opacity(0.14), in: Capsule())
        .foregroundStyle(status.color)
    }
}

struct UsageBar: View {
    let title: String
    let value: Double   // 0...1
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(Tokens.dim)
                Spacer()
                Text(detail).font(.subheadline.weight(.semibold)).foregroundStyle(Tokens.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.line)
                    Capsule().fill(value > 0.9 ? Tokens.bad : Tokens.accent)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: Tokens.barHeight)
        }
    }
}

struct PillButton: View {
    let title: String
    let symbol: String
    var tint: Color = Tokens.accent
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if busy { ProgressView().tint(tint) } else { Image(systemName: symbol) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint)
        }
        .disabled(busy)
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if busy { ProgressView().tint(Tokens.onAccent) } else { Text(title).font(.headline) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Tokens.accent, in: Capsule())
            .foregroundStyle(Tokens.onAccent)
        }
        .disabled(busy)
    }
}

struct ErrorLine: View {
    let text: String?
    var body: some View {
        if let text, !text.isEmpty {
            Text(text).font(.footnote).foregroundStyle(Tokens.bad).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 30, weight: .bold)).foregroundStyle(Tokens.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
