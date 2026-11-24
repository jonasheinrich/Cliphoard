import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var isSelected = false
    var isCopied = false
    var onCopy: () -> Void = {}
    var onToggleSecret: () -> Void = {}

    static let maxLines = 4

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if item.isSecret {
                    Label("••••••••••••", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                        .help("Secret: open or copy it with Touch ID or your password")
                } else {
                    Text(item.text)
                }
            }
            .font(.body.monospaced())
            .lineLimit(Self.maxLines)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)

            CopyButton(isCopied: isCopied, action: onCopy)
                .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    AppIconView(item: item)
                    Text(item.sourceAppName ?? "Unknown app")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                RelativeTimeText(date: item.copiedAt)
                    .help(ItemDisplay.utcTimestamp(item.copiedAt))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 160, alignment: .leading)
        }
        .padding(8)
        .background {
            let shape = RoundedRectangle(cornerRadius: 6)
            ZStack {
                shape.fill(.quaternary.opacity(isHovered ? 1 : 0.5))
                if isSelected {
                    shape.fill(Color.accentColor.opacity(0.15))
                    shape.strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .contentShape(.rect(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy", action: onCopy)
            Button(item.isSecret ? "Not a Secret" : "Mark as Secret", action: onToggleSecret)
        }
    }
}
