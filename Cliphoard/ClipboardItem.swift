import Foundation

/// A single text entry captured from the clipboard.
struct ClipboardItem: Equatable {
    let text: String
    let copiedAt: Date
    /// Name of the frontmost app when the text was copied, if known.
    let sourceAppName: String?
    /// Bundle identifier of that app, if known.
    let sourceBundleID: String?
}
