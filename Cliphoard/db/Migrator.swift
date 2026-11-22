import Foundation
import SQLite3

/// One schema change, loaded from `Migrations/NNNN_description.sql`.
///
/// The number prefix is the schema version the migration upgrades to.
/// To change the schema, add a new file with the next number; never edit a
/// migration that has already shipped, since existing databases have run it.
nonisolated struct Migration: Sendable {
    let version: Int32
    let name: String
    let sql: String

    /// Migrations shipped in the app bundle. Xcode copies the `.sql` files
    /// into the bundle's Resources folder (without their subfolder).
    static func bundled(in bundle: Bundle = .main) throws -> [Migration] {
        try load(bundle.urls(forResourcesWithExtension: "sql", subdirectory: nil) ?? [])
    }

    /// Migrations in `directory`, e.g. the source folder in tests.
    static func load(from directory: URL) throws -> [Migration] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try load(files.filter { $0.pathExtension == "sql" })
    }

    /// Parses `NNNN_description.sql` files, sorted by version.
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

/// Brings a database up to the latest schema version.
///
/// The current version is stored in SQLite's `user_version` (0 for a new
/// database). Each pending migration runs in its own transaction together
/// with the version bump, so a failure leaves the database at the last
/// fully applied version.
nonisolated struct Migrator {
    struct MigrationError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = "Migration error: \(description)" }
    }

    let migrations: [Migration]

    /// Checks that versions run 1, 2, 3, … without gaps or duplicates.
    init(_ migrations: [Migration]) throws {
        guard !migrations.isEmpty else { throw MigrationError("no migrations found") }
        for (index, migration) in migrations.enumerated() where migration.version != Int32(index + 1) {
            throw MigrationError("expected version \(index + 1), found \(migration.name)")
        }
        self.migrations = migrations
    }

    var latestVersion: Int32 { migrations.last?.version ?? 0 }

    /// Applies every migration newer than the database's version.
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
