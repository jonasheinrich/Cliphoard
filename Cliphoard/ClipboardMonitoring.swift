import Observation

protocol ClipboardMonitoring: AnyObject, Observable {
    var items: [ClipboardItem] { get }
    var hasMore: Bool { get }
    var filter: ClipboardFilter { get }
    var apps: [SourceApp] { get }

    func loadMore()
    func setFilter(_ filter: ClipboardFilter)
    func copy(_ item: ClipboardItem)
    /// The item's text, decrypted for secrets. Callers check `SecretVault`
    /// first.
    func reveal(_ item: ClipboardItem) -> String?
    @discardableResult
    func setSecret(_ item: ClipboardItem, _ isSecret: Bool) -> ClipboardItem?
    func start()
    func stop()
}
