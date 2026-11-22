import Foundation
import SQLite3

nonisolated final class ClipboardStore {
    enum StoreError: Error, CustomStringConvertible {
        case sqlite(String)

        var description: String {
            switch self {
            case .sqlite(let message): "SQLite error: \(message)"
            }
        }
    }

    private let db: OpaquePointer

    /// Takes ownership of `db` and closes it on deinit.
    init(db: OpaquePointer) {
        self.db = db
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Queries

    @discardableResult
    func insert(_ item: ClipboardItem) throws -> ClipboardItem {
        let statement = try prepare("""
            INSERT INTO items (text, copied_at, source_app_name, source_bundle_id)
            VALUES (?, ?, ?, ?)
            """)
        defer { sqlite3_finalize(statement) }

        bind(item.text, to: 1, in: statement)
        sqlite3_bind_double(statement, 2, item.copiedAt.timeIntervalSince1970)
        bind(item.sourceAppName, to: 3, in: statement)
        bind(item.sourceBundleID, to: 4, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError("insert") }

        var saved = item
        saved.id = sqlite3_last_insert_rowid(db)
        return saved
    }

    /// Keyset pagination: continues after `cursor`, so new items don't shift
    /// pages.
    func items(
        matching filter: ClipboardFilter = ClipboardFilter(),
        before cursor: ClipboardItem? = nil,
        limit: Int
    ) throws -> [ClipboardItem] {
        var conditions: [String] = []
        var values: [SQLValue] = []

        if !filter.text.isEmpty {
            conditions.append(#"text LIKE ? ESCAPE '\'"#)
            values.append(.text("%\(Self.escapeLike(filter.text))%"))
        }
        switch filter.app {
        case .all:
            break
        case .unknown:
            conditions.append("source_bundle_id IS NULL")
        case .app(let bundleID):
            conditions.append("source_bundle_id = ?")
            values.append(.text(bundleID))
        }
        if let since = filter.since {
            conditions.append("copied_at >= ?")
            values.append(.double(since.timeIntervalSince1970))
        }
        if let cursor, let cursorID = cursor.id {
            let copiedAt = cursor.copiedAt.timeIntervalSince1970
            conditions.append("(copied_at < ? OR (copied_at = ? AND id < ?))")
            values += [.double(copiedAt), .double(copiedAt), .int(cursorID)]
        }

        var sql = "SELECT id, text, copied_at, source_app_name, source_bundle_id FROM items"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY copied_at DESC, id DESC LIMIT ?"
        values.append(.int(Int64(limit)))

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(values, in: statement)

        var result: [ClipboardItem] = []
        result.reserveCapacity(limit)
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: result.append(item(from: statement))
            case SQLITE_DONE: return result
            default: throw lastError("select items")
            }
        }
    }

    func sourceApps() throws -> [SourceApp] {
        // With a single MAX() aggregate, SQLite takes the other bare columns
        // from the row holding the maximum, so each app gets its latest name.
        let statement = try prepare("""
            SELECT source_bundle_id, source_app_name, MAX(copied_at), COUNT(*)
            FROM items
            GROUP BY source_bundle_id
            """)
        defer { sqlite3_finalize(statement) }

        var apps: [SourceApp] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                let bundleID = string(at: 0, in: statement)
                apps.append(SourceApp(
                    bundleID: bundleID,
                    name: bundleID == nil ? "Unknown app" : (string(at: 1, in: statement) ?? bundleID!),
                    itemCount: Int(sqlite3_column_int64(statement, 3))
                ))
            case SQLITE_DONE:
                return apps.sorted(by: SourceApp.displayOrder)
            default:
                throw lastError("select source apps")
            }
        }
    }

    private static func escapeLike(_ text: String) -> String {
        text.replacingOccurrences(of: #"\"#, with: #"\\"#)
            .replacingOccurrences(of: "%", with: #"\%"#)
            .replacingOccurrences(of: "_", with: #"\_"#)
    }

    // MARK: - SQLite helpers

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw lastError("prepare")
        }
        return statement
    }

    /// SQLITE_TRANSIENT: SQLite copies the string.
    private var transient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private enum SQLValue {
        case text(String)
        case double(Double)
        case int(Int64)
    }

    private func bind(_ values: [SQLValue], in statement: OpaquePointer) {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let text): bind(text, to: index, in: statement)
            case .double(let number): sqlite3_bind_double(statement, index, number)
            case .int(let number): sqlite3_bind_int64(statement, index, number)
            }
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, transient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func string(at index: Int32, in statement: OpaquePointer) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }

    private func item(from statement: OpaquePointer) -> ClipboardItem {
        ClipboardItem(
            id: sqlite3_column_int64(statement, 0),
            text: string(at: 1, in: statement) ?? "",
            copiedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
            sourceAppName: string(at: 3, in: statement),
            sourceBundleID: string(at: 4, in: statement)
        )
    }

    private func lastError(_ context: String) -> StoreError {
        .sqlite("\(context): \(String(cString: sqlite3_errmsg(db)))")
    }
}
