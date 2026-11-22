import Observation

/// What the UI needs from a clipboard monitor.
///
/// `ClipboardMonitor` is the real implementation; previews use
/// `PreviewClipboardMonitor` with fixed sample data.
protocol ClipboardMonitoring: AnyObject, Observable {
    /// Loaded history, newest first. Grows as `loadMore()` fetches pages.
    var items: [ClipboardItem] { get }
    /// Whether older items exist that haven't been loaded yet.
    var hasMore: Bool { get }

    /// Fetches the next page of older items, if any.
    func loadMore()
    func start()
    func stop()
}
