import SwiftUI
import AppKit

struct ContentView: View {
    let monitor: any ClipboardMonitoring
    var vault = SecretVault()

    private static let prefetchDistance = 20

    @State private var path: [ClipboardItem] = []
    @State private var isShowingHelp = false
    @State private var selectedID: Int64?
    @State private var visibleIDs: Set<Int64> = []
    @FocusState private var isListFocused: Bool
    @State private var copiedID: Int64?

    @State private var searchText = ""
    @State private var appFilter: AppFilter = .all
    @State private var timeframe: Timeframe = .anyTime
    private static let searchDelay: Duration = .milliseconds(200)
    @FocusState private var isSearchFocused: Bool
    @State private var tabMonitor: Any?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                FilterBar(
                    searchText: $searchText,
                    app: $appFilter,
                    timeframe: $timeframe,
                    apps: monitor.apps,
                    searchFocus: $isSearchFocused,
                    onSubmitSearch: focusFirstResult
                )
                .padding([.horizontal, .top])

                if !monitor.items.isEmpty {
                    history
                } else if monitor.filter.isActive {
                    ContentUnavailableView(
                        "No matching items",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search, app or timeframe.")
                    )
                } else {
                    ContentUnavailableView(
                        "No text on the clipboard",
                        systemImage: "doc.on.clipboard",
                        description: Text("Copy some text and it will appear here.")
                    )
                }
            }
            .navigationTitle("Clipboard History")
            .toolbar {
                // Same spot and size as the detail page's back button, so the
                // toolbar height doesn't jump between pages.
                ToolbarItem(placement: .navigation) {
                    Button { isShowingHelp.toggle() } label: {
                        Image(systemName: "questionmark.circle")
                            .frame(width: 32, height: 32)
                    }
                    .help("Keyboard shortcuts")
                    .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
                        KeyboardHelpView()
                    }
                }
            }
            .navigationDestination(for: ClipboardItem.self) { pushed in
                // The pushed value goes stale when the item is (un)marked as
                // secret, so look up the current one.
                let item = current(pushed)
                ClipboardItemDetailView(
                    item: item,
                    revealedText: item.isSecret ? monitor.reveal(item) : nil,
                    onCopy: { copy(item) },
                    onToggleSecret: { toggleSecret(item) }
                )
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background {
            // Without a Dock icon the app menu never shows, so its ⌘, item
            // can't be relied on.
            Button("Settings") { openSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onChange(of: path) {
            if path.isEmpty { isListFocused = true }
        }
        .onChange(of: vault.unlockedUntil) {
            if vault.unlockedUntil == nil, path.contains(where: { current($0).isSecret }) {
                path.removeAll()
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled else { return }
            applyFilter()
        }
        .onChange(of: appFilter) { applyFilter() }
        .onChange(of: timeframe) { applyFilter() }
        .onChange(of: isSearchFocused) {
            if isSearchFocused { selectedID = nil }
        }
        .onAppear(perform: installTabMonitor)
        .onDisappear(perform: removeTabMonitor)
    }

    /// The text field consumes Tab before `onKeyPress` sees it, hence the event
    /// monitor.
    private func installTabMonitor() {
        guard tabMonitor == nil else { return }
        tabMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let tabKeyCode: UInt16 = 48
            guard event.keyCode == tabKeyCode,
                  event.modifierFlags.isDisjoint(with: [.shift, .command, .option, .control]),
                  isSearchFocused,
                  !monitor.items.isEmpty
            else { return event }
            focusFirstResult()
            return nil
        }
    }

    private func removeTabMonitor() {
        if let tabMonitor { NSEvent.removeMonitor(tabMonitor) }
        tabMonitor = nil
    }

    private func applyFilter() {
        monitor.setFilter(ClipboardFilter(
            text: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            app: appFilter,
            since: timeframe.startDate()
        ))
    }

    private static let typeToSearchCharacters = CharacterSet.alphanumerics.union(["/"])
    private static let listShortcutKeys: Set<String> = ["j", "k", "l", "c"]

    private func startSearch(typing text: String) {
        isSearchFocused = true
        guard !text.isEmpty else { return }
        // Focusing the field selects its text, so the typed character would
        // replace the search. Append it at the end instead once focus lands.
        DispatchQueue.main.async {
            guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
            editor.insertText(text, replacementRange: editor.selectedRange())
        }
    }

    private func focusFirstResult() {
        applyFilter()
        selectedID = monitor.items.first?.id
        isListFocused = true
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(monitor.items.enumerated()), id: \.element.id) { index, item in
                        // A tap gesture rather than a Button, so the row's own
                        // copy button can sit inside it.
                        ClipboardItemRow(
                            item: item,
                            isSelected: isSelected(item),
                            isCopied: copiedID != nil && item.id == copiedID,
                            onCopy: { copy(item) },
                            onToggleSecret: { toggleSecret(item) }
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
            .onKeyPress(keys: [.downArrow, "j"]) { press in
                guard press.hasNoCommandModifiers else { return .ignored }
                return moveSelection(by: 1, proxy: proxy)
            }
            .onKeyPress(keys: [.upArrow, "k"]) { press in
                guard press.hasNoCommandModifiers else { return .ignored }
                return moveSelection(by: -1, proxy: proxy)
            }
            .onKeyPress(.return) { openSelection() }
            .onKeyPress(keys: [.rightArrow, "l"]) { press in
                guard press.hasNoCommandModifiers else { return .ignored }
                return openSelection()
            }
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
            .onKeyPress(characters: Self.typeToSearchCharacters) { press in
                guard press.hasNoCommandModifiers,
                      !Self.listShortcutKeys.contains(press.characters.lowercased())
                else { return .ignored }
                startSearch(typing: press.characters == "/" ? "" : press.characters)
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
            newIndex = items.firstIndex(where: isVisible) ?? 0
        } else {
            newIndex = items.lastIndex(where: isVisible) ?? 0
        }

        let id = items[newIndex].id
        selectedID = id
        proxy.scrollTo(id)
        return .handled
    }

    private func openSelection() -> KeyPress.Result {
        guard let index = selectedIndex else { return .ignored }
        open(monitor.items[index])
        return .handled
    }

    private func current(_ item: ClipboardItem) -> ClipboardItem {
        monitor.items.first { $0.id == item.id } ?? item
    }

    private func copy(_ item: ClipboardItem) {
        Task {
            if item.isSecret {
                guard await vault.authorize("copy a secret clipboard item") else { return }
            }
            monitor.copy(item)
            copiedID = item.id
            try? await Task.sleep(for: copyFeedbackDuration)
            if copiedID == item.id { copiedID = nil }
        }
    }

    private func open(_ item: ClipboardItem) {
        selectedID = item.id
        Task {
            if item.isSecret {
                guard await vault.authorize("show a secret clipboard item") else { return }
            }
            path.append(item)
        }
    }

    private func toggleSecret(_ item: ClipboardItem) {
        Task {
            // Unmarking shows the text in the list.
            if item.isSecret {
                guard await vault.authorize("show a secret clipboard item in the list") else { return }
            }
            monitor.setSecret(item, !item.isSecret)
        }
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
