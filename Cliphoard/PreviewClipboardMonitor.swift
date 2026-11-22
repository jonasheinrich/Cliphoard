#if DEBUG
import Foundation
import Observation

/// A monitor with fixed data for SwiftUI previews. It never touches the
/// real clipboard.
@Observable
final class PreviewClipboardMonitor: ClipboardMonitoring {
    var latestItem: ClipboardItem?

    init(latestItem: ClipboardItem? = .sampleShort) {
        self.latestItem = latestItem
    }

    func start() {}
    func stop() {}
}

extension ClipboardItem {
    static let sampleShort = ClipboardItem(
        text: "https://developer.apple.com/documentation/swiftui",
        copiedAt: .now.addingTimeInterval(-20),
        sourceAppName: "Safari",
        sourceBundleID: "com.apple.Safari"
    )

    static let sampleCode = ClipboardItem(
        text: """
        func greet(_ name: String) -> String {
            "Hello, \\(name)!"
        }
        """,
        copiedAt: .now.addingTimeInterval(-5 * 60),
        sourceAppName: "Xcode",
        sourceBundleID: "com.apple.dt.Xcode"
    )

    static let sampleLong = ClipboardItem(
        text: Array(
            repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            count: 20
        ).joined(separator: " "),
        copiedAt: .now.addingTimeInterval(-3 * 3600),
        sourceAppName: "Terminal",
        sourceBundleID: "com.apple.Terminal"
    )

    static let sampleUnknownApp = ClipboardItem(
        text: "copied via pbcopy",
        copiedAt: .now.addingTimeInterval(-2 * 86400),
        sourceAppName: nil,
        sourceBundleID: nil
    )
}
#endif
