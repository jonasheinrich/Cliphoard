import SwiftUI

/// One clipboard entry in the history list: text (capped at a few lines) on
/// the left, source app and time on the right, inside a rounded grey box.
struct ClipboardItemRow: View {
    let item: ClipboardItem
    /// Highlighted as the keyboard selection.
    var isSelected = false

    /// Longer text is cut off with "…"; the detail page shows all of it.
    static let maxLines = 4

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.text)
                .font(.body.monospaced())
                .lineLimit(Self.maxLines)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        // Make the whole box clickable, not just the text.
        .contentShape(.rect(cornerRadius: 6))
        .onHover { isHovered = $0 }
    }
}
