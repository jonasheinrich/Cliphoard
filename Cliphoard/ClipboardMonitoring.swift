import Observation

protocol ClipboardMonitoring: AnyObject, Observable {
    var items: [ClipboardItem] { get }
    var hasMore: Bool { get }
    var filter: ClipboardFilter { get }
    var apps: [SourceApp] { get }

    func loadMore()
    func setFilter(_ filter: ClipboardFilter)
    func copy(_ item: ClipboardItem)
    func start()
    func stop()
}
