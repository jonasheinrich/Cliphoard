import AppKit
import Observation

/// Watches the system clipboard and keeps the clipboard history.
///
/// macOS has no clipboard-change notification, so we poll
/// `NSPasteboard.changeCount`, a cheap counter that increments on every copy.
/// We only read the contents when that counter changes.
///
/// New items are saved to the `ClipboardStore` and put on top of `items`.
/// Older history is loaded from the store page by page via `loadMore()`.
@Observable
final class ClipboardMonitor: ClipboardMonitoring {
    /// How often the clipboard's change counter is checked.
    static let pollInterval: Duration = .milliseconds(100)
    /// How many items are fetched from the database at a time.
    static let pageSize = 100

    private(set) var items: [ClipboardItem] = []
    private(set) var hasMore = false

    private let pasteboard: NSPasteboard
    /// `nil` if the database couldn't be opened; items then live in memory only.
    private let store: ClipboardStore?
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?
    /// Ids for items that couldn't be saved, so the list can still tell them
    /// apart. Negative, so they never clash with database ids.
    private var nextUnsavedID: Int64 = -1

    init(pasteboard: NSPasteboard = .general, store: ClipboardStore? = nil) {
        self.pasteboard = pasteboard
        self.store = store
        // Start at -1 so the first check always reads the current contents.
        self.lastChangeCount = -1
        loadNextPage()
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkForChanges()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func loadMore() {
        guard hasMore else { return }
        loadNextPage()
    }

    private func loadNextPage() {
        guard let store else { return }
        do {
            let page = try store.items(before: items.last, limit: Self.pageSize)
            items.append(contentsOf: page)
            hasMore = page.count == Self.pageSize
        } catch {
            print("Could not load clipboard history: \(error)")
            hasMore = false
        }
    }

    private func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        let isFirstCheck = lastChangeCount == -1
        lastChangeCount = changeCount

        // Text only for now; images, files etc. are ignored.
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }

        // Don't store the same text twice in a row. This also prevents a new
        // row on every launch when the clipboard still holds the last item.
        guard text != items.first?.text else { return }

        // macOS doesn't record which app wrote to the clipboard, so we use the
        // frontmost app at the moment we notice the change as a best guess.
        // On the first check the text was copied before we were running, so
        // the frontmost app says nothing about where it came from.
        let app = isFirstCheck ? nil : NSWorkspace.shared.frontmostApplication
        var item = ClipboardItem(
            text: text,
            copiedAt: .now,
            sourceAppName: app?.localizedName,
            sourceBundleID: app?.bundleIdentifier
        )

        do {
            if let store { item = try store.insert(item) }
        } catch {
            print("Could not save clipboard item: \(error)")
        }
        if item.id == nil {
            item.id = nextUnsavedID
            nextUnsavedID -= 1
        }
        items.insert(item, at: 0)
    }
}
