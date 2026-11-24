import SwiftUI

struct KeyboardHelpView: View {
    private struct Shortcut: Identifiable {
        let keys: [String]
        let action: String
        var id: String { action }
    }

    private let sections: [(title: String, shortcuts: [Shortcut])] = [
        ("List", [
            Shortcut(keys: ["↓", "j"], action: "Next item"),
            Shortcut(keys: ["↑", "k"], action: "Previous item"),
            Shortcut(keys: ["→", "l", "↩"], action: "Open item"),
            Shortcut(keys: ["c"], action: "Copy item"),
            Shortcut(keys: ["esc"], action: "Clear selection"),
            Shortcut(keys: ["/", "a–z", "0–9"], action: "Search"),
        ]),
        ("Search", [
            Shortcut(keys: ["⇥"], action: "Go to first result"),
            Shortcut(keys: ["⇧⇥"], action: "Back to search from the list"),
        ]),
        ("Detail", [
            Shortcut(keys: ["←", "h"], action: "Back to the list"),
            Shortcut(keys: ["c"], action: "Copy item"),
        ]),
        ("App", [
            Shortcut(keys: ["⌘,"], action: "Settings"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(sections, id: \.title) { section in
                    GridRow {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .gridCellColumns(2)
                            .padding(.top, 4)
                    }
                    ForEach(section.shortcuts) { shortcut in
                        GridRow {
                            HStack(spacing: 4) {
                                ForEach(shortcut.keys, id: \.self, content: KeyCap.init)
                            }
                            Text(shortcut.action)
                        }
                    }
                }
            }

            Text("j, k, l and c don't start a search; use / first.\nRight-click an item to mark it as secret.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .fixedSize()
    }
}

private struct KeyCap: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.callout.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 22)
            .background(.quaternary, in: .rect(cornerRadius: 4))
    }
}

#if DEBUG
#Preview {
    KeyboardHelpView()
}
#endif
