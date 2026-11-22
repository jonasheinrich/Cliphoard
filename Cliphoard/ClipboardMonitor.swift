import AppKit
import Observation

/// Watches the system clipboard and publishes the most recent text item.
///
/// macOS has no clipboard-change notification, so we poll
/// `NSPasteboard.changeCount`, a cheap counter that increments on every copy.
/// We only read the contents when that counter changes.
@Observable
final class ClipboardMonitor {
    /// The most recent text on the clipboard, or `nil` if it holds no text.
    private(set) var latestText: String?
    /// When `latestText` was last updated.
    private(set) var lastChanged: Date?

    private let pasteboard: NSPasteboard
    private let interval: Duration
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general, interval: Duration = .milliseconds(500)) {
        self.pasteboard = pasteboard
        self.interval = interval
        // Start at -1 so the first check always reads the current contents.
        self.lastChangeCount = -1
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkForChanges()
                try? await Task.sleep(for: self?.interval ?? .milliseconds(500))
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
        latestText = text
        lastChanged = .now
    }
}
