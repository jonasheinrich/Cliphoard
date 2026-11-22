import Foundation

nonisolated struct ClipboardItem: Hashable, Sendable {
    var id: Int64? = nil
    let text: String
    let copiedAt: Date
    let sourceAppName: String?
    let sourceBundleID: String?
}
