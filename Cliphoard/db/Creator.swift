import Foundation
import SQLite3

/// Creates and opens the per-user history database, ready to use.
///
/// The database lives in the user's Application Support directory, so every
/// macOS user gets their own history, protected by normal file permissions.
/// (If the app is ever sandboxed, the same API resolves to the container.)
nonisolated enum DatabaseCreator {
    struct CreatorError: Error, CustomStringConvertible {
        let description: String
    }

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

    /// Opens (or creates) the database at `url` and applies pending schema
    /// migrations: the bundled `Migrations/*.sql` files unless `migrations`
    /// is given (tests pass the source folder's files).
    ///
    /// The caller owns the returned connection and must close it with
    /// `sqlite3_close`; `ClipboardStore` does that when it's released.
    static func open(at url: URL, migrations: [Migration]? = nil) throws -> OpaquePointer {
        let migrator = try Migrator(migrations ?? Migration.bundled())

        // Create the file ourselves so it starts out owner-only. SQLite gives
        // its -wal/-shm side files the same permissions as the main file.
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let db = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            sqlite3_close(handle)
            throw CreatorError(description: "cannot open \(url.path): \(message)")
        }

        do {
            // Outside a transaction, so not part of the migrations.
            guard sqlite3_exec(db, "PRAGMA journal_mode = WAL", nil, nil, nil) == SQLITE_OK else {
                throw CreatorError(description: "enable WAL: \(String(cString: sqlite3_errmsg(db)))")
            }
            try migrator.migrate(db)
        } catch {
            sqlite3_close(db)
            throw error
        }
        return db
    }
}
