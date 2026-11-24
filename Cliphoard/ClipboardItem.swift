import Foundation

nonisolated struct ClipboardItem: Hashable, Sendable {
    var id: Int64? = nil
    /// Empty for secrets; their text is only in `ciphertext`.
    let text: String
    let copiedAt: Date
    let sourceAppName: String?
    let sourceBundleID: String?
    var isSecret = false
    var ciphertext: Data? = nil
}

extension ClipboardItem {
    func with(text: String, isSecret: Bool, ciphertext: Data?) -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: text,
            copiedAt: copiedAt,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID,
            isSecret: isSecret,
            ciphertext: ciphertext
        )
    }
}
