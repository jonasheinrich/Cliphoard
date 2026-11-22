import Foundation
import SQLite3

/// Persists clipboard items in a per-user SQLite database.
///
/// The database lives in the user's Application Support directory, so every
/// macOS user gets their own history, protected by normal file permissions.
/// (If the app is ever sandboxed, the same API resolves to the container.)
///
/// Not thread-safe by design: the owner (the main-actor `ClipboardMonitor`)
/// serializes all access.
nonisolated final class ClipboardStore {
    enum StoreError: Error, CustomStringConvertible {
        case sqlite(String)

        var description: String {
            switch self {
            case .sqlite(let message): "SQLite error: \(message)"
            }
        }
    }

    /// Location of the database file.
    let url: URL
    private let db: OpaquePointer

    /// `~/Library/Application Support/<bundle id>/history.sqlite`, creating the
    /// directory (owner-only) if needed.
    static func defaultURL() throws -> URL {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "dev.local.Cliphoard",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Clipboard history is sensitive: only the owner may read it.
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return directory.appendingPathComponent("history.sqlite")
    }

    init(url: URL) throws {
        self.url = url

        // Create the file ourselves so it starts out owner-only. SQLite gives
        // its -wal/-shm side files the same permissions as the main file.
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            sqlite3_close(handle)
            throw StoreError.sqlite("cannot open \(url.path): \(message)")
        }
        db = handle

        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Queries

    /// Saves `item` and returns it with its new database `id`.
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

    /// Items newest first, starting after `cursor` (exclusive), at most `limit`.
    ///
    /// Uses keyset pagination: the next page continues from the last item
    /// already loaded rather than from a row offset, so items copied in the
    /// meantime don't shift pages or cause duplicates. Pass `nil` for the
    /// first page. The `copied_at` index covers this query (SQLite indexes
    /// include the rowid `id` as a tiebreaker).
    func items(before cursor: ClipboardItem? = nil, limit: Int) throws -> [ClipboardItem] {
        let columns = "SELECT id, text, copied_at, source_app_name, source_bundle_id FROM items"
        let order = "ORDER BY copied_at DESC, id DESC LIMIT ?3"
        let statement: OpaquePointer
        if let cursor, let cursorID = cursor.id {
            statement = try prepare("""
                \(columns)
                WHERE copied_at < ?1 OR (copied_at = ?1 AND id < ?2)
                \(order)
                """)
            sqlite3_bind_double(statement, 1, cursor.copiedAt.timeIntervalSince1970)
            sqlite3_bind_int64(statement, 2, cursorID)
        } else {
            statement = try prepare("\(columns) \(order)")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 3, Int64(limit))

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

    // MARK: - Schema

    /// Schema versions are tracked in SQLite's `user_version`. To change the
    /// schema, add another `if version < N` step; never edit an old one.
    private func migrate() throws {
        try execute("PRAGMA journal_mode = WAL")

        let version = try userVersion()
        if version < 1 {
            try execute("""
                BEGIN;
                CREATE TABLE items (
                    id               INTEGER PRIMARY KEY AUTOINCREMENT,
                    text             TEXT NOT NULL,
                    copied_at        REAL NOT NULL, -- seconds since 1970-01-01 UTC
                    source_app_name  TEXT,
                    source_bundle_id TEXT
                );
                CREATE INDEX items_copied_at ON items (copied_at);
                PRAGMA user_version = 1;
                COMMIT;
                """)
        }
    }

    private func userVersion() throws -> Int32 {
        let statement = try prepare("PRAGMA user_version")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw lastError("read user_version") }
        return sqlite3_column_int(statement, 0)
    }

    // MARK: - SQLite helpers

    private func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(message)
            throw StoreError.sqlite(text)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw lastError("prepare")
        }
        return statement
    }

    /// Tells SQLite to copy bound strings, since Swift's buffers are temporary.
    private var transient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
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
