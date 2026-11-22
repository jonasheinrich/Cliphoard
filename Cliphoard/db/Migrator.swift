import Foundation
import SQLite3

/// Never edit a shipped migration; add a new numbered file instead.
nonisolated struct Migration: Sendable {
    let version: Int32
    let name: String
    let sql: String

    /// Xcode copies the .sql files flat into Resources.
    static func bundled(in bundle: Bundle = .main) throws -> [Migration] {
        try load(bundle.urls(forResourcesWithExtension: "sql", subdirectory: nil) ?? [])
    }

    static func load(from directory: URL) throws -> [Migration] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try load(files.filter { $0.pathExtension == "sql" })
    }

    static func load(_ files: [URL]) throws -> [Migration] {
        try files.map { file in
            let name = file.deletingPathExtension().lastPathComponent
            guard let prefix = name.split(separator: "_").first, let version = Int32(prefix) else {
                throw Migrator.MigrationError("\(file.lastPathComponent) doesn't start with a version number")
            }
            return Migration(version: version, name: name, sql: try String(contentsOf: file, encoding: .utf8))
        }
        .sorted { $0.version < $1.version }
    }
}

nonisolated struct Migrator {
    struct MigrationError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = "Migration error: \(description)" }
    }

    let migrations: [Migration]

    init(_ migrations: [Migration]) throws {
        guard !migrations.isEmpty else { throw MigrationError("no migrations found") }
        for (index, migration) in migrations.enumerated() where migration.version != Int32(index + 1) {
            throw MigrationError("expected version \(index + 1), found \(migration.name)")
        }
        self.migrations = migrations
    }

    var latestVersion: Int32 { migrations.last?.version ?? 0 }

    func migrate(_ db: OpaquePointer) throws {
        let current = try userVersion(db)
        guard current <= latestVersion else {
            throw MigrationError(
                "database is at version \(current), but this app only knows up to \(latestVersion)"
            )
        }

        for migration in migrations where migration.version > current {
            do {
                try execute("BEGIN", on: db)
                try execute(migration.sql, on: db)
                try execute("PRAGMA user_version = \(migration.version)", on: db)
                try execute("COMMIT", on: db)
            } catch {
                try? execute("ROLLBACK", on: db)
                throw MigrationError("\(migration.name) failed: \(error)")
            }
        }
    }

    private func userVersion(_ db: OpaquePointer) throws -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            throw MigrationError(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw MigrationError(String(cString: sqlite3_errmsg(db)))
        }
        return sqlite3_column_int(statement, 0)
    }

    private func execute(_ sql: String, on db: OpaquePointer) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(message)
            throw MigrationError(text)
        }
    }
}
