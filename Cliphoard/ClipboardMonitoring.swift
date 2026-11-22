import Observation

/// What the UI needs from a clipboard monitor.
///
/// `ClipboardMonitor` is the real implementation; previews use
/// `PreviewClipboardMonitor` with fixed sample data.
protocol ClipboardMonitoring: AnyObject, Observable {
    /// The most recent text item on the clipboard, or `nil` if none seen yet.
    var latestItem: ClipboardItem? { get }

    func start()
    func stop()
}
