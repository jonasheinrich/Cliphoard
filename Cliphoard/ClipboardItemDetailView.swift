import SwiftUI

/// Full view of one clipboard item, opened by clicking a row in the history.
///
/// Keyboard: ← goes back to the list, C copies the item.
struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    var onCopy: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AppIconView(item: item, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.sourceAppName ?? "Unknown app")
                        .font(.headline)
                    RelativeTimeText(date: item.copiedAt)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.copiedAt, format: .dateTime.year().month().day().hour().minute().second())
                    Text(ItemDisplay.utcTimestamp(item.copiedAt))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospacedDigit())
                .textSelection(.enabled)
            }

            ScrollView {
                Text(item.text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))

            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle(item.sourceAppName ?? "Clipboard item")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CopyButton(isCopied: isCopied, action: copy)
            }
        }
        // Take keyboard focus on open so ← works right away.
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) {
            dismiss()
            return .handled
        }
        .onKeyPress(keys: ["c"]) { press in
            guard press.hasNoCommandModifiers else { return .ignored }
            copy()
            return .handled
        }
    }

    private func copy() {
        onCopy()
        isCopied = true
        Task {
            try? await Task.sleep(for: copyFeedbackDuration)
            isCopied = false
        }
    }

    private var summary: String {
        let characters = item.text.count
        let lines = item.text.split(separator: "\n", omittingEmptySubsequences: false).count
        return "\(characters) characters · \(lines) \(lines == 1 ? "line" : "lines")"
    }
}

#if DEBUG
#Preview("Code") {
    NavigationStack {
        ClipboardItemDetailView(item: ClipboardItem.samples(count: 2)[1])
    }
}

#Preview("Long text") {
    NavigationStack {
        ClipboardItemDetailView(item: ClipboardItem.samples(count: 3)[2])
    }
}
#endif
