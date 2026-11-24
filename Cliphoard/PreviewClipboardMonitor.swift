#if DEBUG
import Foundation
import Observation

@Observable
final class PreviewClipboardMonitor: ClipboardMonitoring {
    private(set) var items: [ClipboardItem] = []
    private(set) var filter = ClipboardFilter()
    var hasMore: Bool { items.count < matchingItems.count }

    var apps: [SourceApp] {
        Dictionary(grouping: allItems, by: \.sourceBundleID)
            .map { bundleID, items in
                SourceApp(
                    bundleID: bundleID,
                    name: bundleID == nil ? "Unknown app" : (items[0].sourceAppName ?? bundleID!),
                    itemCount: items.count
                )
            }
            .sorted(by: SourceApp.displayOrder)
    }

    private var allItems: [ClipboardItem]
    private var secretTexts: [Int64: String] = [:]
    private let pageSize: Int
    private var matchingItems: [ClipboardItem] { allItems.filter(filter.matches) }

    init(items: [ClipboardItem] = ClipboardItem.samples(count: 250), pageSize: Int = 100) {
        self.allItems = items
        self.pageSize = pageSize
        loadMore()
    }

    func loadMore() {
        let next = matchingItems.dropFirst(items.count).prefix(pageSize)
        items.append(contentsOf: next)
    }

    func setFilter(_ newFilter: ClipboardFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        items = []
        loadMore()
    }

    func copy(_ item: ClipboardItem) {
        guard item.text != allItems.first?.text else { return }
        let nextID = (allItems.compactMap(\.id).max() ?? 0) + 1
        let copy = ClipboardItem(
            id: nextID, text: item.text, copiedAt: .now,
            sourceAppName: item.sourceAppName, sourceBundleID: item.sourceBundleID
        )
        allItems.insert(copy, at: 0)
        if filter.matches(copy) { items.insert(copy, at: 0) }
    }

    func reveal(_ item: ClipboardItem) -> String? {
        guard item.isSecret else { return item.text }
        return item.id.flatMap { secretTexts[$0] } ?? ClipboardItem.sampleSecret
    }

    @discardableResult
    func setSecret(_ item: ClipboardItem, _ isSecret: Bool) -> ClipboardItem? {
        guard item.isSecret != isSecret, let id = item.id, let text = reveal(item) else { return nil }
        secretTexts[id] = text
        let updated = item.with(text: isSecret ? "" : text, isSecret: isSecret, ciphertext: nil)
        if let index = allItems.firstIndex(where: { $0.id == id }) { allItems[index] = updated }
        if let index = items.firstIndex(where: { $0.id == id }) { items[index] = updated }
        return updated
    }

    func start() {}
    func stop() {}
}

extension ClipboardItem {
    static let sampleSecret = "c0rrect-Horse-Battery!"

    static func samples(count: Int) -> [ClipboardItem] {
        let now = Date.now
        let handWritten: [(String, TimeInterval, String?, String?)] = [
            ("https://developer.apple.com/documentation/swiftui", 20, "Safari", "com.apple.Safari"),
            ("""
            func greet(_ name: String) -> String {
                "Hello, \\(name)!"
            }
            """, 5 * 60, "Xcode", "com.apple.dt.Xcode"),
            (Array(
                repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                count: 20
            ).joined(separator: " "), 3 * 3600, "Terminal", "com.apple.Terminal"),
            ("", 4 * 3600, "1Password", "com.1password.1password"),
            ("copied via pbcopy", 2 * 86400, nil, nil),
        ]
        let apps = [
            ("Safari", "com.apple.Safari"),
            ("Notes", "com.apple.Notes"),
            ("Terminal", "com.apple.Terminal"),
            ("Xcode", "com.apple.dt.Xcode"),
        ]

        return (0..<count).map { index in
            let id = Int64(count - index)
            if index < handWritten.count {
                let (text, age, appName, bundleID) = handWritten[index]
                return ClipboardItem(
                    id: id, text: text, copiedAt: now.addingTimeInterval(-age),
                    sourceAppName: appName, sourceBundleID: bundleID,
                    isSecret: text.isEmpty
                )
            }
            let app = apps[index % apps.count]
            return ClipboardItem(
                id: id,
                text: "Sample item #\(index + 1)",
                copiedAt: now.addingTimeInterval(-3 * 86400 - Double(index) * 7 * 60),
                sourceAppName: app.0,
                sourceBundleID: app.1
            )
        }
    }
}
#endif
