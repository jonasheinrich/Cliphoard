import SwiftUI

struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    /// The decrypted text of a secret.
    var revealedText: String? = nil
    var onCopy: () -> Void = {}
    var onToggleSecret: () -> Void = {}

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
                Text(text)
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
                Button(action: onToggleSecret) {
                    Image(systemName: item.isSecret ? "lock.fill" : "lock.open")
                }
                .help(item.isSecret ? "Secret: click to show it in the list again" : "Mark as secret")
            }
            ToolbarItem(placement: .primaryAction) {
                CopyButton(isCopied: isCopied, action: copy)
            }
        }
        // Take keyboard focus on open so ← works right away.
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(keys: [.leftArrow, "h"]) { press in
            guard press.hasNoCommandModifiers else { return .ignored }
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

    private var text: String {
        revealedText ?? item.text
    }

    private var summary: String {
        let characters = text.count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
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
