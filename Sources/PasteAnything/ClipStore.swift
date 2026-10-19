import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum StoreError: LocalizedError {
    case sqlite(String)

    var errorDescription: String? {
        switch self {
        case .sqlite(let message): "Error de base de datos: \(message)"
        }
    }
}

/// Historial guardado en un archivo SQLite local, solo legible por el usuario.
@MainActor
final class ClipStore {
    static let didChange = Notification.Name("ClipStoreDidChange")

    let fileURL: URL
    private var db: OpaquePointer?

    init() throws {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteAnything", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        fileURL = directory.appendingPathComponent("history.sqlite")

        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    private func migrate() throws {
        try execute("""
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS clips(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kind TEXT NOT NULL,
                text TEXT,
                data BLOB,
                source_app TEXT,
                source_bundle TEXT,
                created_at REAL NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                hash TEXT NOT NULL UNIQUE
            );
            CREATE TABLE IF NOT EXISTS collections(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                symbol TEXT NOT NULL,
                color TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            """)
        if try !columnExists("collection_id", in: "clips") {
            try execute("ALTER TABLE clips ADD COLUMN collection_id INTEGER;")
        }
        try execute("""
            CREATE INDEX IF NOT EXISTS clips_order ON clips(pinned DESC, created_at DESC);
            CREATE INDEX IF NOT EXISTS clips_collection ON clips(collection_id);
            """)
    }

    // MARK: - Clips

    /// Guarda un elemento. Si ya existía el mismo contenido, solo lo sube al principio.
    func save(_ clip: NewClip, date: Date = Date(), pinned: Bool = false, collectionID: Int64? = nil) throws {
        let statement = try prepare("""
            INSERT INTO clips(kind, text, data, source_app, source_bundle, created_at, hash, pinned, collection_id)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(hash) DO UPDATE SET
                created_at = max(created_at, excluded.created_at),
                source_app = excluded.source_app,
                source_bundle = excluded.source_bundle
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, clip.kind.rawValue)
        bind(statement, 2, clip.text)
        bind(statement, 3, clip.data)
        bind(statement, 4, clip.sourceApp)
        bind(statement, 5, clip.sourceBundleID)
        sqlite3_bind_double(statement, 6, date.timeIntervalSince1970)
        bind(statement, 7, clip.hash)
        sqlite3_bind_int(statement, 8, pinned ? 1 : 0)
        bind(statement, 9, collectionID)
        try step(statement)
        notifyChange()
    }

    func fetch(query: String, filter: ClipFilter, limit: Int) throws -> [ClipItem] {
        let statement = try prepare("""
            SELECT id, kind, text, data, source_app, source_bundle, created_at, pinned, collection_id
            FROM clips
            WHERE (?1 = '' OR text LIKE ?2 ESCAPE '\\')
              AND (?3 = 0 OR (?3 = 1 AND pinned = 1) OR (?3 = 2 AND collection_id = ?4))
            ORDER BY pinned DESC, created_at DESC
            LIMIT ?5
            """)
        defer { sqlite3_finalize(statement) }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        bind(statement, 1, trimmed)
        bind(statement, 2, "%\(escaped)%")
        switch filter {
        case .recent:
            sqlite3_bind_int(statement, 3, 0)
        case .pinned:
            sqlite3_bind_int(statement, 3, 1)
        case .collection(let id):
            sqlite3_bind_int(statement, 3, 2)
            sqlite3_bind_int64(statement, 4, id)
        }
        sqlite3_bind_int(statement, 5, Int32(clamping: limit))

        var items: [ClipItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(ClipItem(
                id: sqlite3_column_int64(statement, 0),
                kind: ClipKind(rawValue: columnText(statement, 1) ?? "") ?? .text,
                text: columnText(statement, 2),
                data: columnData(statement, 3),
                sourceApp: columnText(statement, 4),
                sourceBundleID: columnText(statement, 5),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
                isPinned: sqlite3_column_int(statement, 7) != 0,
                collectionID: columnInt64(statement, 8)
            ))
        }
        return items
    }

    func setPinned(_ pinned: Bool, id: Int64) throws {
        try run("UPDATE clips SET pinned = ? WHERE id = ?") { statement in
            sqlite3_bind_int(statement, 1, pinned ? 1 : 0)
            sqlite3_bind_int64(statement, 2, id)
        }
    }

    func setCollection(_ collectionID: Int64?, clipID: Int64) throws {
        try run("UPDATE clips SET collection_id = ? WHERE id = ?") { statement in
            self.bind(statement, 1, collectionID)
            sqlite3_bind_int64(statement, 2, clipID)
        }
    }

    /// Sube un elemento al principio del historial (por ejemplo, al pegarlo).
    func touch(id: Int64) throws {
        try run("UPDATE clips SET created_at = ? WHERE id = ?") { statement in
            sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
            sqlite3_bind_int64(statement, 2, id)
        }
    }

    func delete(id: Int64) throws {
        try run("DELETE FROM clips WHERE id = ?") { statement in
            sqlite3_bind_int64(statement, 1, id)
        }
    }

    /// Borra todo excepto los fijados y los que están en una colección.
    func deleteUnpinned() throws {
        try run("DELETE FROM clips WHERE pinned = 0 AND collection_id IS NULL") { _ in }
        try execute("VACUUM;")
    }

    /// Aplica el límite de elementos y la antigüedad máxima. Los fijados y los
    /// que están en una colección no se borran.
    func trim(keeping limit: Int, olderThanDays days: Int) throws {
        try run("""
            DELETE FROM clips WHERE pinned = 0 AND collection_id IS NULL AND id NOT IN (
                SELECT id FROM clips WHERE pinned = 0 AND collection_id IS NULL
                ORDER BY created_at DESC LIMIT ?
            )
            """) { statement in
            sqlite3_bind_int(statement, 1, Int32(clamping: limit))
        }
        guard days > 0 else { return }
        try run("DELETE FROM clips WHERE pinned = 0 AND collection_id IS NULL AND created_at < ?") { statement in
            sqlite3_bind_double(statement, 1, Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970)
        }
    }

    // MARK: - Colecciones

    func collections() throws -> [ClipCollection] {
        let statement = try prepare("SELECT id, name, symbol, color FROM collections ORDER BY created_at")
        defer { sqlite3_finalize(statement) }
        var result: [ClipCollection] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(ClipCollection(
                id: sqlite3_column_int64(statement, 0),
                name: columnText(statement, 1) ?? "",
                symbol: columnText(statement, 2) ?? "folder.fill",
                color: CollectionColor(rawValue: columnText(statement, 3) ?? "") ?? .blue
            ))
        }
        return result
    }

    @discardableResult
    func addCollection(name: String, symbol: String, color: CollectionColor) throws -> Int64 {
        try run("INSERT INTO collections(name, symbol, color, created_at) VALUES(?, ?, ?, ?)") { statement in
            self.bind(statement, 1, name)
            self.bind(statement, 2, symbol)
            self.bind(statement, 3, color.rawValue)
            sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
        }
        return sqlite3_last_insert_rowid(db)
    }

    func updateCollection(_ collection: ClipCollection) throws {
        try run("UPDATE collections SET name = ?, symbol = ?, color = ? WHERE id = ?") { statement in
            self.bind(statement, 1, collection.name)
            self.bind(statement, 2, collection.symbol)
            self.bind(statement, 3, collection.color.rawValue)
            sqlite3_bind_int64(statement, 4, collection.id)
        }
    }

    /// Borra la colección. Sus clips vuelven al historial general.
    func deleteCollection(id: Int64) throws {
        try run("UPDATE clips SET collection_id = NULL WHERE collection_id = ?") { statement in
            sqlite3_bind_int64(statement, 1, id)
        }
        try run("DELETE FROM collections WHERE id = ?") { statement in
            sqlite3_bind_int64(statement, 1, id)
        }
        notifyChange()
    }

    // MARK: - SQLite

    private func run(_ sql: String, bindings: (OpaquePointer) -> Void) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bindings(statement)
        try step(statement)
        if sqlite3_changes(db) > 0 {
            notifyChange()
        }
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "desconocido"
            sqlite3_free(error)
            throw StoreError.sqlite(message)
        }
    }

    private func columnExists(_ column: String, in table: String) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(table))")
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if columnText(statement, 1) == column {
                return true
            }
        }
        return false
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func step(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Int64?) {
        if let value {
            sqlite3_bind_int64(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Data?) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        _ = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func columnInt64(_ statement: OpaquePointer, _ index: Int32) -> Int64? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, index)
    }

    private func columnData(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        guard let pointer = sqlite3_column_blob(statement, index) else { return nil }
        return Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
