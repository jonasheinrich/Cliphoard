#if DEBUG
import Foundation
import Observation

/// A monitor with fixed data for SwiftUI previews. It never touches the
/// real clipboard or database, but pages through its samples like the real
/// monitor does, so infinite scrolling can be tried in the canvas.
@Observable
final class PreviewClipboardMonitor: ClipboardMonitoring {
    private(set) var items: [ClipboardItem] = []
    var hasMore: Bool { items.count < allItems.count }

    private let allItems: [ClipboardItem]
    private let pageSize: Int

    init(items: [ClipboardItem] = ClipboardItem.samples(count: 250), pageSize: Int = 100) {
        self.allItems = items
        self.pageSize = pageSize
        loadMore()
    }

    func loadMore() {
        let next = allItems.dropFirst(items.count).prefix(pageSize)
        items.append(contentsOf: next)
    }

    /// Only simulates the history entry; the real clipboard is left alone.
    func copy(_ item: ClipboardItem) {
        guard item.text != items.first?.text else { return }
        let nextID = (items.compactMap(\.id).max() ?? 0) + 1
        items.insert(ClipboardItem(
            id: nextID, text: item.text, copiedAt: .now,
            sourceAppName: item.sourceAppName, sourceBundleID: item.sourceBundleID
        ), at: 0)
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
