import Foundation
import SQLite3

final class AnkiDatabase {
    private var database: OpaquePointer?

    init(url: URL) throws {
        try Self.stripCheckPointedWALMode(at: url)
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(database)
            database = nil
            throw AnkiImportError.invalid("не удалось открыть базу SQLite")
        }
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 16 * 1024 * 1024)
        registerUnicaseCollation()
        try rows("PRAGMA trusted_schema = OFF") { _ in }
    }

    /// Anki's schema declares indexes and column collations with the
    /// app-defined "unicase" collation. On some SQLite builds (iOS) the query
    /// planner reports "no query solution" for tables whose usable indexes
    /// depend on a collation that is not registered, so a read-only connection
    /// cannot scan them. Register a case-insensitive comparison — close enough
    /// for import: our queries never order by the collated columns, the
    /// callback exists only to keep the planner satisfied.
    private func registerUnicaseCollation() {
        sqlite3_create_collation(database, "unicase", SQLITE_UTF8, nil, { _, leftCount, left, rightCount, right in
            let left = UnsafeRawBufferPointer(start: left, count: Int(leftCount))
            let right = UnsafeRawBufferPointer(start: right, count: Int(rightCount))
            var index = 0
            while index < left.count && index < right.count {
                let a = left[index], b = right[index]
                if a != b {
                    // ASCII case-fold: enough for a collation that only exists
                    // to satisfy the planner, never to order our results.
                    let folded = a >= 65 && a <= 90 ? a + 32 : a
                    let foldedB = b >= 65 && b <= 90 ? b + 32 : b
                    return folded < foldedB ? -1 : (folded > foldedB ? 1 : 0)
                }
                index += 1
            }
            if left.count != right.count { return left.count < right.count ? -1 : 1 }
            return 0
        })
    }

    deinit { sqlite3_close(database) }

    /// Modern Anki exports leave the SQLite header in WAL mode after the final
    /// checkpoint: the extracted file carries write/read version 2 without a
    /// companion `-wal` file, and SQLITE_OPEN_READONLY cannot open such a
    /// database ("unable to open database file"). On our own extracted copy we
    /// flip the header back to rollback-journal mode — the same two-byte change
    /// SQLite itself performs when converting a checkpointed WAL database to
    /// journal_mode=DELETE.
    private static func stripCheckPointedWALMode(at url: URL) throws {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        guard let header = try reader.read(upToCount: 20), header.count == 20,
              header.starts(with: Array("SQLite format 3\u{0}".utf8)),
              header[18] == 2, header[19] == 2,
              !FileManager.default.fileExists(atPath: url.path + "-wal") else { return }
        let writer = try FileHandle(forUpdating: url)
        defer { try? writer.close() }
        try writer.seek(toOffset: 18)
        try writer.write(contentsOf: [1, 1])
    }

    func rows(_ sql: String, _ visit: (OpaquePointer) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let snippet = sql.prefix(60)
            throw AnkiImportError.invalid("неподдерживаемая или повреждённая структура SQLite [\(snippet)]: \(String(cString: sqlite3_errmsg(database)))")
        }
        defer { sqlite3_finalize(statement) }
        while true {
            try Task.checkCancellation()
            switch sqlite3_step(statement) {
            case SQLITE_ROW: try visit(statement)
            case SQLITE_DONE: return
            default: throw AnkiImportError.invalid("ошибка чтения SQLite")
            }
        }
    }

    func read() throws -> AnkiCollection {
        var normalized = false
        try rows("SELECT name FROM sqlite_master WHERE type='table' AND name='notetypes'") { _ in normalized = true }
        var decks: [AnkiDeck] = []
        var models: [AnkiNoteType] = []
        if normalized {
            try rows("SELECT id, name FROM decks ORDER BY id") { row in
                decks.append(.init(id: sqlite3_column_int64(row, 0), name: Self.text(row, 1).replacingOccurrences(of: "\u{1f}", with: "::")))
            }
            var fields: [Int64: [String]] = [:]
            try rows("SELECT ntid, name FROM fields ORDER BY ntid, ord") { row in
                fields[sqlite3_column_int64(row, 0), default: []].append(Self.text(row, 1))
            }
            var templates: [Int64: [AnkiTemplate]] = [:]
            try rows("SELECT ntid, ord, name, config FROM templates ORDER BY ntid, ord") { row in
                let config = try AnkiProtobuf(Self.blob(row, 3))
                templates[sqlite3_column_int64(row, 0), default: []].append(.init(
                    ordinal: Int(sqlite3_column_int64(row, 1)), name: Self.text(row, 2),
                    question: try config.string(1), answer: try config.string(2)))
            }
            try rows("SELECT id, name, config FROM notetypes ORDER BY id") { row in
                let id = sqlite3_column_int64(row, 0)
                let config = try AnkiProtobuf(Self.blob(row, 2))
                models.append(.init(id: id, name: Self.text(row, 1), isCloze: config.numbers[1] == 1,
                                    fields: fields[id] ?? [], templates: templates[id] ?? [], css: try config.string(3)))
            }
        } else {
            try rows("SELECT models, decks FROM col") { row in
                let rawModels = try JSONDecoder().decode([String: LegacyModel].self, from: Data(Self.text(row, 0).utf8))
                models = rawModels.values.map { model in
                    AnkiNoteType(id: model.id, name: model.name, isCloze: model.type == 1,
                        fields: model.flds.sorted { $0.ord < $1.ord }.map(\.name),
                        templates: model.tmpls.map { .init(ordinal: $0.ord, name: $0.name, question: $0.qfmt, answer: $0.afmt) }, css: model.css)
                }.sorted { $0.id < $1.id }
                decks = try JSONDecoder().decode([String: AnkiDeck].self, from: Data(Self.text(row, 1).utf8)).values.sorted { $0.id < $1.id }
            }
        }
        var notes: [AnkiNote] = []
        try rows("SELECT id, guid, mid, flds, tags FROM notes ORDER BY id") { row in
            guard notes.count < 500_000 else { throw AnkiImportError.limit }
            notes.append(.init(id: sqlite3_column_int64(row, 0), guid: Self.text(row, 1), noteTypeID: sqlite3_column_int64(row, 2),
                               fields: Self.text(row, 3).components(separatedBy: "\u{1f}"), tags: Self.text(row, 4).split(whereSeparator: \.isWhitespace).map(String.init)))
        }
        let scheduling = ["type", "queue", "due", "ivl", "factor", "reps", "lapses", "left", "odue", "odid", "flags"]
        var cards: [AnkiCard] = []
        try rows("SELECT id, nid, did, ord, \(scheduling.joined(separator: ",")) FROM cards ORDER BY id") { row in
            guard cards.count < 1_000_000 else { throw AnkiImportError.limit }
            var values: [String: Int64] = [:]
            for (index, key) in scheduling.enumerated() { values[key] = sqlite3_column_int64(row, Int32(index + 4)) }
            cards.append(.init(id: sqlite3_column_int64(row, 0), noteID: sqlite3_column_int64(row, 1), deckID: sqlite3_column_int64(row, 2),
                               ordinal: Int(sqlite3_column_int64(row, 3)), scheduling: values))
        }
        guard Set(models.map(\.id)).count == models.count, Set(decks.map(\.id)).count == decks.count else {
            throw AnkiImportError.invalid("повторяющиеся идентификаторы типов заметок или колод")
        }
        let modelMap = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        let noteMap = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let deckIDs = Set(decks.map(\.id))
        for note in notes {
            guard let model = modelMap[note.noteTypeID], model.fields.count == note.fields.count,
                  Set(model.fields).count == model.fields.count, !model.templates.isEmpty else {
                throw AnkiImportError.invalid("поля заметки не соответствуют её типу")
            }
        }
        for card in cards {
            guard let note = noteMap[card.noteID], let model = modelMap[note.noteTypeID], deckIDs.contains(card.deckID),
                  card.ordinal >= 0, card.ordinal < 65_535,
                  model.isCloze || model.templates.contains(where: { $0.ordinal == card.ordinal }) else {
                throw AnkiImportError.invalid("карточка ссылается на отсутствующую заметку, колоду или шаблон")
            }
        }
        guard !cards.isEmpty else { throw AnkiImportError.invalid("в пакете нет карточек") }
        return AnkiCollection(decks: decks, noteTypes: models, notes: notes, cards: cards)
    }

    private static func text(_ row: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(row, index) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: pointer, count: Int(sqlite3_column_bytes(row, index))), as: UTF8.self)
    }

    private static func blob(_ row: OpaquePointer, _ index: Int32) -> Data {
        guard let pointer = sqlite3_column_blob(row, index) else { return Data() }
        return Data(bytes: pointer, count: Int(sqlite3_column_bytes(row, index)))
    }
}

private struct LegacyModel: Decodable {
    struct Field: Decodable { let name: String; let ord: Int }
    struct Template: Decodable { let name: String; let ord: Int; let qfmt: String; let afmt: String }
    let id: Int64
    let name: String
    let type: Int
    let css: String
    let flds: [Field]
    let tmpls: [Template]
}
