import AppKit
import Observation

/// Watches the system clipboard and publishes the most recent text item.
///
/// macOS has no clipboard-change notification, so we poll
/// `NSPasteboard.changeCount`, a cheap counter that increments on every copy.
/// We only read the contents when that counter changes.
@Observable
final class ClipboardMonitor {
    /// How often the clipboard's change counter is checked.
    static let pollInterval: Duration = .milliseconds(100)

    /// The most recent text item on the clipboard, or `nil` if none seen yet.
    private(set) var latestItem: ClipboardItem?

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        // Start at -1 so the first check always reads the current contents.
        self.lastChangeCount = -1
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

    private func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        // Text only for now; images, files etc. are ignored.
        guard let text = pasteboard.string(forType: .string) else { return }
        // macOS doesn't record which app wrote to the clipboard, so we use the
        // frontmost app at the moment we notice the change as a best guess.
        let app = NSWorkspace.shared.frontmostApplication
        latestItem = ClipboardItem(
            text: text,
            copiedAt: .now,
            sourceAppName: app?.localizedName,
            sourceBundleID: app?.bundleIdentifier
        )
    }
}
