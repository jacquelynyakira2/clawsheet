import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct SQLiteStore: HelperStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appendingPathComponent("ClaudeCodeHelper", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("ClaudeCodeHelper.sqlite")
        }
        try withDatabase { database in
            try Self.createTables(database)
        }
    }

    public func load() throws -> HelperSnapshot {
        try withDatabase { database in
            try Self.createTables(database)
            let tips: [TipItem] = try Self.readJSONRows(database, table: "tips")
            if tips.isEmpty {
                return try reset()
            }
            let sources: [SourceItem] = try Self.readJSONRows(database, table: "sources")
            let updates: [UpdateEntry] = try Self.readJSONRows(database, table: "updates")
            let settings: [AppSettings] = try Self.readJSONRows(database, table: "settings")
            var snapshot = HelperSnapshot(
                tips: tips,
                sources: sources.isEmpty ? OfficialSources.defaultSources : sources,
                updates: updates,
                settings: settings.first ?? AppSettings()
            )
            if !snapshot.settings.pinSelectionCustomized {
                snapshot.settings.pinnedTipIDs = BaselineTips.defaultPinnedTipIDs(in: snapshot.tips)
            }
            return snapshot
        }
    }

    public func save(_ snapshot: HelperSnapshot) throws {
        try withDatabase { database in
            try Self.createTables(database)
            try Self.replaceRows(database, table: "tips", values: snapshot.tips)
            try Self.replaceRows(database, table: "sources", values: snapshot.sources)
            try Self.replaceRows(database, table: "updates", values: snapshot.updates)
            try Self.replaceRows(database, table: "settings", values: [snapshot.settings])
        }
    }

    public func reset() throws -> HelperSnapshot {
        let snapshot = HelperSnapshot(
            tips: BaselineTips.load(),
            sources: OfficialSources.defaultSources,
            updates: [],
            settings: AppSettings(pinnedTipIDs: BaselineTips.defaultPinnedTipIDs(in: BaselineTips.load()))
        )
        try save(snapshot)
        return snapshot
    }

    private func withDatabase<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open(fileURL.path, &database) == SQLITE_OK, let database else {
            throw SQLiteStoreError.openFailed
        }
        defer { sqlite3_close(database) }
        return try work(database)
    }

    private static func createTables(_ database: OpaquePointer) throws {
        let statements = [
            "CREATE TABLE IF NOT EXISTS tips (id TEXT PRIMARY KEY, json BLOB NOT NULL)",
            "CREATE TABLE IF NOT EXISTS sources (id TEXT PRIMARY KEY, json BLOB NOT NULL)",
            "CREATE TABLE IF NOT EXISTS updates (id TEXT PRIMARY KEY, json BLOB NOT NULL)",
            "CREATE TABLE IF NOT EXISTS settings (id TEXT PRIMARY KEY, json BLOB NOT NULL)"
        ]
        for statement in statements {
            try execute(statement, database: database)
        }
    }

    private static func replaceRows<T: Encodable & Identifiable>(_ database: OpaquePointer, table: String, values: [T]) throws where T.ID == String {
        try execute("DELETE FROM \(table)", database: database)
        let sql = "INSERT OR REPLACE INTO \(table) (id, json) VALUES (?, ?)"
        for value in values {
            let data = try JSONEncoder.helperEncoder.encode(value)
            try insert(id: value.id, data: data, sql: sql, database: database)
        }
    }

    private static func replaceRows(_ database: OpaquePointer, table: String, values: [AppSettings]) throws {
        try execute("DELETE FROM \(table)", database: database)
        let sql = "INSERT OR REPLACE INTO \(table) (id, json) VALUES (?, ?)"
        for value in values {
            let data = try JSONEncoder.helperEncoder.encode(value)
            try insert(id: "app-settings", data: data, sql: sql, database: database)
        }
    }

    private static func readJSONRows<T: Decodable>(_ database: OpaquePointer, table: String) throws -> [T] {
        let sql = "SELECT json FROM \(table)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var values: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            guard let bytes = sqlite3_column_blob(statement, 0), byteCount > 0 else { continue }
            let data = Data(bytes: bytes, count: byteCount)
            values.append(try JSONDecoder.helperDecoder.decode(T.self, from: data))
        }
        return values
    }

    private static func insert(id: String, data: Data, sql: String, database: OpaquePointer) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id, -1, sqliteTransient)
        data.withUnsafeBytes { rawBuffer in
            _ = sqlite3_bind_blob(statement, 2, rawBuffer.baseAddress, Int32(data.count), sqliteTransient)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.writeFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func execute(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteStoreError.writeFailed(String(cString: sqlite3_errmsg(database)))
        }
    }
}

enum SQLiteStoreError: LocalizedError {
    case openFailed
    case prepareFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed:
            "Unable to open SQLite database."
        case .prepareFailed(let message):
            "Unable to prepare SQLite statement: \(message)"
        case .writeFailed(let message):
            "Unable to write SQLite data: \(message)"
        }
    }
}
