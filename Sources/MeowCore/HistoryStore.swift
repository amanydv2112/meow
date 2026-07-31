import CSQLite
import Foundation

public protocol HistoryStore: Sendable {
    func insert(_ record: HistoryRecord) throws
    func recent(limit: Int) throws -> [HistoryRecord]
    func deleteAll() throws
}

public final class SQLiteHistoryStore: HistoryStore, @unchecked Sendable {
    private let database: OpaquePointer?
    private let lock = NSLock()

    public init(databaseURL: URL) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &db, flags, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            sqlite3_close(db)
            throw FlowError.httpError(statusCode: 0, message: message)
        }
        database = db
        try migrate()
    }

    deinit {
        sqlite3_close(database)
    }

    public static func defaultDatabaseURL(appName: String = "EchoType") throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent(appName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.sqlite")
    }

    public func insert(_ record: HistoryRecord) throws {
        try locked {
            let sql = """
            INSERT INTO history (
                id, created_at, app_name, bundle_identifier, raw_transcript,
                polished_text, provider, model, duration, status, error_message
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }

            bind(record.id.uuidString, to: statement, at: 1)
            sqlite3_bind_double(statement, 2, record.createdAt.timeIntervalSince1970)
            bind(record.appName, to: statement, at: 3)
            bind(record.bundleIdentifier, to: statement, at: 4)
            bind(record.rawTranscript, to: statement, at: 5)
            bind(record.polishedText, to: statement, at: 6)
            bind(record.provider, to: statement, at: 7)
            bind(record.model, to: statement, at: 8)
            if let duration = record.duration {
                sqlite3_bind_double(statement, 9, duration)
            } else {
                sqlite3_bind_null(statement, 9)
            }
            bind(record.status.rawValue, to: statement, at: 10)
            bind(record.errorMessage, to: statement, at: 11)

            try stepDone(statement)
        }
    }

    public func recent(limit: Int = 20) throws -> [HistoryRecord] {
        try locked {
            let statement = try prepare(
                """
                SELECT id, created_at, app_name, bundle_identifier, raw_transcript,
                       polished_text, provider, model, duration, status, error_message
                FROM history
                ORDER BY created_at DESC
                LIMIT ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(limit))

            var records: [HistoryRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = UUID(uuidString: columnString(statement, 0) ?? ""),
                    let provider = columnString(statement, 6),
                    let model = columnString(statement, 7),
                    let statusValue = columnString(statement, 9),
                    let status = HistoryStatus(rawValue: statusValue)
                else {
                    continue
                }

                records.append(
                    HistoryRecord(
                        id: id,
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                        appName: columnString(statement, 2),
                        bundleIdentifier: columnString(statement, 3),
                        rawTranscript: columnString(statement, 4),
                        polishedText: columnString(statement, 5),
                        provider: provider,
                        model: model,
                        duration: sqlite3_column_type(statement, 8) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 8),
                        status: status,
                        errorMessage: columnString(statement, 10)
                    )
                )
            }
            return records
        }
    }

    public func deleteAll() throws {
        try locked {
            let statement = try prepare("DELETE FROM history;")
            defer { sqlite3_finalize(statement) }
            try stepDone(statement)
        }
    }

    private func migrate() throws {
        try locked {
            let sql = """
            CREATE TABLE IF NOT EXISTS history (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                app_name TEXT,
                bundle_identifier TEXT,
                raw_transcript TEXT,
                polished_text TEXT,
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                duration REAL,
                status TEXT NOT NULL,
                error_message TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_history_created_at ON history(created_at DESC);
            """
            if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
                throw sqliteError()
            }
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            throw sqliteError()
        }
        return statement
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        if sqlite3_step(statement) != SQLITE_DONE {
            throw sqliteError()
        }
    }

    private func sqliteError() -> Error {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error"
        return FlowError.httpError(statusCode: 0, message: message)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let pointer = sqlite3_column_text(statement, index) else {
        return nil
    }
    return String(cString: pointer)
}
