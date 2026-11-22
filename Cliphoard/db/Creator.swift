import Foundation
import SQLite3

nonisolated enum DatabaseCreator {
    struct CreatorError: Error, CustomStringConvertible {
        let description: String
    }

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

    /// Caller owns the returned connection.
    static func open(at url: URL, migrations: [Migration]? = nil) throws -> OpaquePointer {
        let migrator = try Migrator(migrations ?? Migration.bundled())

        // Created up front so it's owner-only; SQLite copies these permissions
        // to -wal/-shm.
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
