import SwiftUI

/// The clipboard history, newest first. Clicking an item opens its detail page.
///
/// Keyboard: ↑/↓ move the selection, ↩ or → opens it, C copies it, Esc clears
/// it. With nothing
/// selected, ↓ starts at the topmost visible row and ↑ at the bottommost.
struct ContentView: View {
    let monitor: any ClipboardMonitoring

    /// Fetch the next page when a row this close to the end appears, so new
    /// items are usually ready before the user reaches the bottom.
    private static let prefetchDistance = 20

    @State private var path: [ClipboardItem] = []
    /// Keyboard selection; `nil` means nothing is selected.
    @State private var selectedID: Int64?
    /// Rows at least half on screen, used to pick where keyboard navigation
    /// starts when nothing is selected.
    @State private var visibleIDs: Set<Int64> = []
    @FocusState private var isListFocused: Bool
    /// Item whose copy button currently shows the "copied" checkmark.
    @State private var copiedID: Int64?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if monitor.items.isEmpty {
                    ContentUnavailableView(
                        "No text on the clipboard",
                        systemImage: "doc.on.clipboard",
                        description: Text("Copy some text and it will appear here.")
                    )
                } else {
                    history
                }
            }
            .navigationTitle("Clipboard History")
            .toolbar {
                // Mirrors the detail page's back button in the same spot, so
                // the toolbar keeps its height and layout when navigating.
                ToolbarItem(placement: .navigation) {
                    // Square frame so the glass background becomes a circle
                    // the size of the back button instead of a narrow pill.
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                }
            }
            .navigationDestination(for: ClipboardItem.self) { item in
                ClipboardItemDetailView(item: item) { monitor.copy(item) }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        // Back on the list: take keyboard focus again so the arrows work.
        .onChange(of: path) {
            if path.isEmpty { isListFocused = true }
        }
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Lazy: only rows on (or near) the screen are created.
                LazyVStack(spacing: 6) {
                    ForEach(Array(monitor.items.enumerated()), id: \.element.id) { index, item in
                        // A tap gesture rather than a Button, so the row's own
                        // copy button can sit inside it.
                        ClipboardItemRow(
                            item: item,
                            isSelected: isSelected(item),
                            isCopied: copiedID != nil && item.id == copiedID,
                            onCopy: { copy(item) }
                        )
                        .onTapGesture { open(item) }
                        .accessibilityAddTraits(.isButton)
                        .onAppear {
                            if index >= monitor.items.count - Self.prefetchDistance {
                                monitor.loadMore()
                            }
                        }
                        .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                            guard let id = item.id else { return }
                            if isVisible {
                                visibleIDs.insert(id)
                            } else {
                                visibleIDs.remove(id)
                            }
                        }
                    }

                    if monitor.hasMore {
                        ProgressView()
                            .controlSize(.small)
                            .padding()
                            .onAppear { monitor.loadMore() }
                    }
                }
                .padding()
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isListFocused)
            .onAppear { isListFocused = true }
            .onKeyPress(.downArrow) { moveSelection(by: 1, proxy: proxy) }
            .onKeyPress(.upArrow) { moveSelection(by: -1, proxy: proxy) }
            .onKeyPress(.return) { openSelection() }
            .onKeyPress(.rightArrow) { openSelection() }
            .onKeyPress(keys: ["c"]) { press in
                guard press.hasNoCommandModifiers, let index = selectedIndex else { return .ignored }
                copy(monitor.items[index])
                return .handled
            }
            .onKeyPress(.escape) {
                guard selectedID != nil else { return .ignored }
                selectedID = nil
                return .handled
            }
        }
    }

    // MARK: - Selection

    private func isSelected(_ item: ClipboardItem) -> Bool {
        selectedID != nil && item.id == selectedID
    }

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return monitor.items.firstIndex { $0.id == selectedID }
    }

    private func isVisible(_ item: ClipboardItem) -> Bool {
        item.id.map(visibleIDs.contains) ?? false
    }

    private func moveSelection(by offset: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        let items = monitor.items
        guard !items.isEmpty else { return .ignored }

        let newIndex: Int
        if let current = selectedIndex {
            newIndex = min(max(current + offset, 0), items.count - 1)
        } else if offset > 0 {
            // Nothing selected, ↓: start at the top of the screen.
            newIndex = items.firstIndex(where: isVisible) ?? 0
        } else {
            // Nothing selected, ↑: start at the bottom of the screen.
            newIndex = items.lastIndex(where: isVisible) ?? 0
        }

        let id = items[newIndex].id
        selectedID = id
        // No anchor: scroll only as far as needed to show the row.
        proxy.scrollTo(id)
        return .handled
    }

    private func openSelection() -> KeyPress.Result {
        guard let index = selectedIndex else { return .ignored }
        open(monitor.items[index])
        return .handled
    }

    private func copy(_ item: ClipboardItem) {
        monitor.copy(item)
        copiedID = item.id
        Task {
            try? await Task.sleep(for: copyFeedbackDuration)
            if copiedID == item.id { copiedID = nil }
        }
    }

    private func open(_ item: ClipboardItem) {
        selectedID = item.id
        path.append(item)
    }
}

#if DEBUG
#Preview("History (250 items)") {
    ContentView(monitor: PreviewClipboardMonitor())
}

#Preview("Single item") {
    ContentView(monitor: PreviewClipboardMonitor(items: ClipboardItem.samples(count: 1)))
}

#Preview("Empty") {
    ContentView(monitor: PreviewClipboardMonitor(items: []))
}
#endif
