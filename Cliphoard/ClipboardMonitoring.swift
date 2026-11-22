import Observation

/// What the UI needs from a clipboard monitor.
///
/// `ClipboardMonitor` is the real implementation; previews use
/// `PreviewClipboardMonitor` with fixed sample data.
protocol ClipboardMonitoring: AnyObject, Observable {
    /// Loaded history matching `filter`, newest first. Grows as `loadMore()`
    /// fetches pages.
    var items: [ClipboardItem] { get }
    /// Whether older matching items exist that haven't been loaded yet.
    var hasMore: Bool { get }
    /// The active filter; change it with `setFilter(_:)`.
    var filter: ClipboardFilter { get }
    /// Every app in the history (ignoring the filter), for the app picker.
    var apps: [SourceApp] { get }

    /// Fetches the next page of older items, if any.
    func loadMore()
    /// Applies `filter` and reloads the history from its first page.
    func setFilter(_ filter: ClipboardFilter)
    /// Puts `item`'s text back on the clipboard and records that as a new
    /// history entry (keeping the original source app).
    func copy(_ item: ClipboardItem)
    func start()
    func stop()
}
