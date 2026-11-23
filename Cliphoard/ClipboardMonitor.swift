import AppKit
import Observation

/// macOS has no clipboard-change notification, so we poll `changeCount`.
@Observable
final class ClipboardMonitor: ClipboardMonitoring {
    static let pollInterval: Duration = .milliseconds(100)
    static let pageSize = 100

    private(set) var items: [ClipboardItem] = []
    private(set) var hasMore = false
    private(set) var filter = ClipboardFilter()
    private(set) var apps: [SourceApp] = []
    var maxItems: Int {
        didSet { enforceLimit() }
    }

    private let pasteboard: NSPasteboard
    private let store: ClipboardStore?
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?
    /// Newest text regardless of the filter, for skipping repeats.
    private var latestText: String?
    private var unsavedItems: [ClipboardItem] = []
    /// Negative, so they never clash with database ids.
    private var nextUnsavedID: Int64 = -1

    init(
        pasteboard: NSPasteboard = .general,
        store: ClipboardStore? = nil,
        maxItems: Int = HistoryLimit.current
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.maxItems = maxItems
        // Start at -1 so the first check always reads the current contents.
        self.lastChangeCount = -1

        do {
            latestText = try store?.items(limit: 1).first?.text
            apps = try store?.sourceApps() ?? []
        } catch {
            print("Could not read clipboard history: \(error)")
        }
        enforceLimit()
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

    func setFilter(_ newFilter: ClipboardFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        items = []
        hasMore = false
        loadNextPage()
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        // Mark our own write as seen, otherwise polling would record it with
        // Cliphoard (the frontmost app) as the source.
        lastChangeCount = pasteboard.changeCount

        guard item.text != latestText else { return }
        record(ClipboardItem(
            text: item.text,
            copiedAt: .now,
            sourceAppName: item.sourceAppName,
            sourceBundleID: item.sourceBundleID
        ))
    }

    func historyCount() -> Int {
        guard let store else { return unsavedItems.count }
        return (try? store.count()) ?? 0
    }

    func loadMore() {
        guard hasMore else { return }
        loadNextPage()
    }

    private func loadNextPage() {
        guard let store else {
            items = unsavedItems.filter(filter.matches)
            hasMore = false
            return
        }
        do {
            let page = try store.items(matching: filter, before: items.last, limit: Self.pageSize)
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

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }

        // Also avoids a new row on every launch while the clipboard is
        // unchanged.
        guard text != latestText else { return }

        // macOS doesn't record the clipboard's source app, so we guess the
        // frontmost one. On the first check the text predates our launch, so
        // there's no guess.
        let app = isFirstCheck ? nil : NSWorkspace.shared.frontmostApplication
        record(ClipboardItem(
            text: text,
            copiedAt: .now,
            sourceAppName: app?.localizedName,
            sourceBundleID: app?.bundleIdentifier
        ))
    }

    private func record(_ newItem: ClipboardItem) {
        var item = newItem
        do {
            if let store { item = try store.insert(item) }
        } catch {
            print("Could not save clipboard item: \(error)")
        }
        if item.id == nil {
            item.id = nextUnsavedID
            nextUnsavedID -= 1
            unsavedItems.insert(item, at: 0)
        }

        latestText = item.text
        countForSourceApp(item)
        if filter.matches(item) {
            items.insert(item, at: 0)
        }
        enforceLimit()
    }

    private func enforceLimit() {
        guard let store else {
            unsavedItems = Array(unsavedItems.prefix(maxItems))
            let kept = Set(unsavedItems.compactMap(\.id))
            items.removeAll { !kept.contains($0.id ?? 0) }
            return
        }
        do {
            guard try store.prune(keeping: maxItems) > 0 else { return }
            apps = try store.sourceApps()
            guard let oldest = try store.oldestItem() else {
                items = []
                hasMore = false
                return
            }
            items.removeAll { ($0.copiedAt, $0.id ?? 0) < (oldest.copiedAt, oldest.id ?? 0) }
        } catch {
            print("Could not limit clipboard history: \(error)")
        }
    }

    private func countForSourceApp(_ item: ClipboardItem) {
        if let index = apps.firstIndex(where: { $0.bundleID == item.sourceBundleID }) {
            apps[index].itemCount += 1
        } else {
            apps.append(SourceApp(
                bundleID: item.sourceBundleID,
                name: item.sourceBundleID == nil
                    ? "Unknown app"
                    : (item.sourceAppName ?? item.sourceBundleID!),
                itemCount: 1
            ))
            apps.sort(by: SourceApp.displayOrder)
        }
    }
}
