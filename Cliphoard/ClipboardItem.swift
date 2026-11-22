import Foundation

/// A single text entry captured from the clipboard.
nonisolated struct ClipboardItem: Equatable, Sendable {
    /// Row id in the database; `nil` until the item has been saved.
    var id: Int64? = nil
    let text: String
    let copiedAt: Date
    /// Name of the frontmost app when the text was copied, if known.
    let sourceAppName: String?
    /// Bundle identifier of that app, if known.
    let sourceBundleID: String?
}
