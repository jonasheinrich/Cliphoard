-- Clipboard history: one row per copied text.
CREATE TABLE items (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    text             TEXT NOT NULL,
    copied_at        REAL NOT NULL, -- seconds since 1970-01-01 UTC
    source_app_name  TEXT,
    source_bundle_id TEXT
);

-- Newest-first paging. SQLite indexes include the rowid (id) as tiebreaker.
CREATE INDEX items_copied_at ON items (copied_at);
