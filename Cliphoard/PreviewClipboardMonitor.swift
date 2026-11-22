#if DEBUG
import Foundation
import Observation

/// A monitor with fixed data for SwiftUI previews. It never touches the
/// real clipboard or database, but filters and pages through its samples
/// like the real monitor does, so both can be tried in the canvas.
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

    /// Only simulates the history entry; the real clipboard is left alone.
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

    func start() {}
    func stop() {}
}

extension ClipboardItem {
    /// `count` items, newest first: a few hand-written ones covering the
    /// interesting cases, then generated filler spaced 7 minutes apart.
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
                    sourceAppName: appName, sourceBundleID: bundleID
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
