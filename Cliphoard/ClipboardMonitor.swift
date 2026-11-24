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
    var detectSecretsByContent: Bool {
        didSet {
            if detectSecretsByContent { detectExistingSecrets() }
        }
    }

    private let pasteboard: NSPasteboard
    private let store: ClipboardStore?
    private let cipher: SecretCipher
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?
    /// Newest text regardless of the filter, for skipping repeats.
    private var latestText: String?
    /// The newest item while it's a secret we haven't decrypted. Only a new
    /// secret needs comparing with it, and storing that needs the key anyway.
    private var undecryptedLatest: ClipboardItem?
    private var unsavedItems: [ClipboardItem] = []
    /// Negative, so they never clash with database ids.
    private var nextUnsavedID: Int64 = -1

    init(
        pasteboard: NSPasteboard = .general,
        store: ClipboardStore? = nil,
        cipher: SecretCipher = SecretCipher(),
        maxItems: Int = HistoryLimit.current,
        detectSecretsByContent: Bool = SecretDetector.detectsByContent
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.cipher = cipher
        self.maxItems = maxItems
        self.detectSecretsByContent = detectSecretsByContent
        // Start at -1 so the first check always reads the current contents.
        self.lastChangeCount = -1

        do {
            if let newest = try store?.items(limit: 1).first {
                if newest.isSecret {
                    undecryptedLatest = newest
                } else {
                    latestText = newest.text
                }
            }
            apps = try store?.sourceApps() ?? []
        } catch {
            print("Could not read clipboard history: \(error)")
        }
        enforceLimit()
        if detectSecretsByContent, SecretDetector.scannedVersion != SecretDetector.contentCheckVersion {
            detectExistingSecrets()
        }
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
        guard let text = reveal(item) else { return }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if item.isSecret {
            // Tells other clipboard tools not to show or keep it.
            pasteboard.setData(Data(), forType: SecretDetector.concealedType)
        }
        // Mark our own write as seen, otherwise polling would record it with
        // Cliphoard (the frontmost app) as the source.
        lastChangeCount = pasteboard.changeCount

        guard !isRepeat(text, isSecret: item.isSecret) else { return }
        record(text, sourceAppName: item.sourceAppName, sourceBundleID: item.sourceBundleID, isSecret: item.isSecret)
    }

    func reveal(_ item: ClipboardItem) -> String? {
        guard item.isSecret else { return item.text }
        guard let ciphertext = item.ciphertext else { return nil }
        do {
            return try cipher.decrypt(ciphertext)
        } catch {
            print("Could not decrypt secret: \(error)")
            return nil
        }
    }

    @discardableResult
    func setSecret(_ item: ClipboardItem, _ isSecret: Bool) -> ClipboardItem? {
        guard item.isSecret != isSecret, let id = item.id, let text = reveal(item) else { return nil }
        var updated: ClipboardItem
        do {
            if isSecret {
                let ciphertext = try cipher.encrypt(text)
                try store?.makeSecret(id: id, ciphertext: ciphertext, byUser: true)
                store?.checkpoint()
                updated = item.with(text: "", isSecret: true, ciphertext: ciphertext)
            } else {
                try store?.makePlain(id: id, text: text)
                updated = item.with(text: text, isSecret: false, ciphertext: nil)
            }
        } catch {
            print("Could not change secret: \(error)")
            return nil
        }
        replace(updated)
        return updated
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

        // macOS doesn't record the clipboard's source app, so we guess the
        // frontmost one. On the first check the text predates our launch, so
        // there's no guess.
        let app = isFirstCheck ? nil : NSWorkspace.shared.frontmostApplication
        let verdict = SecretDetector.verdict(
            text: text,
            types: pasteboard.types ?? [],
            sourceBundleID: app?.bundleIdentifier,
            byContent: detectSecretsByContent
        )
        guard verdict != .skip else { return }
        // Also avoids a new row on every launch while the clipboard is
        // unchanged.
        guard !isRepeat(text, isSecret: verdict == .secret) else { return }
        record(
            text,
            sourceAppName: app?.localizedName,
            sourceBundleID: app?.bundleIdentifier,
            isSecret: verdict == .secret
        )
    }

    private func isRepeat(_ text: String, isSecret: Bool) -> Bool {
        if isSecret, let pending = undecryptedLatest {
            latestText = reveal(pending)
            undecryptedLatest = nil
        }
        return text == latestText
    }

    private func record(_ text: String, sourceAppName: String?, sourceBundleID: String?, isSecret: Bool) {
        var item = ClipboardItem(
            text: text,
            copiedAt: .now,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID
        )
        if isSecret {
            do {
                item = item.with(text: "", isSecret: true, ciphertext: try cipher.encrypt(text))
            } catch {
                // Better to lose it than to store a secret in plain text.
                print("Could not encrypt secret: \(error)")
                latestText = text
                undecryptedLatest = nil
                return
            }
        }
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

        latestText = text
        undecryptedLatest = nil
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

    /// Runs the content check over items saved before it existed, with an
    /// older version of it, or while it was off. Items the user marked or
    /// unmarked are left alone.
    private func detectExistingSecrets() {
        guard let store else { return }
        do {
            var changed: [Int64: Data] = [:]
            for (id, text) in try store.unreviewedPlainItems() where SecretDetector.looksLikePassword(text) {
                let ciphertext = try cipher.encrypt(text)
                try store.makeSecret(id: id, ciphertext: ciphertext, byUser: false)
                changed[id] = ciphertext
            }
            SecretDetector.scannedVersion = SecretDetector.contentCheckVersion
            guard !changed.isEmpty else { return }
            store.checkpoint()
            items = items.map { item in
                guard let id = item.id, let ciphertext = changed[id] else { return item }
                return item.with(text: "", isSecret: true, ciphertext: ciphertext)
            }
        } catch {
            print("Could not detect secrets: \(error)")
        }
    }

    private func replace(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item }
        if let index = unsavedItems.firstIndex(where: { $0.id == item.id }) { unsavedItems[index] = item }
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
