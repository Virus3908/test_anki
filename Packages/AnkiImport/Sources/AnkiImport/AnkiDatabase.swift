import Foundation
import SQLite3

final class AnkiDatabase {
    private var database: OpaquePointer?

    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(database)
            database = nil
            throw AnkiImportError.invalid("не удалось открыть базу SQLite")
        }
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 16 * 1024 * 1024)
        try rows("PRAGMA trusted_schema = OFF") { _ in }
    }

    deinit { sqlite3_close(database) }

    func rows(_ sql: String, _ visit: (OpaquePointer) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            throw AnkiImportError.invalid("неподдерживаемая или повреждённая структура SQLite: \(detail)")
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
        var creationTime: Int64?
        var hasCollectionTable = false
        try rows("SELECT name FROM sqlite_master WHERE type='table' AND name='col'") { _ in hasCollectionTable = true }
        var hasCreationColumn = false
        if hasCollectionTable {
            try rows("PRAGMA table_info(col)") { row in
                if Self.text(row, 1) == "crt" { hasCreationColumn = true }
            }
        }
        if hasCreationColumn {
            try rows("SELECT crt FROM col LIMIT 1") { row in creationTime = sqlite3_column_int64(row, 0) }
        }
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
        var historyByCard: [Int64: [AnkiReviewLogEntry]] = [:]
        var hasRevlog = false
        try rows("SELECT name FROM sqlite_master WHERE type='table' AND name='revlog'") { _ in hasRevlog = true }
        if hasRevlog {
            var columns: [String: String] = [:]
            try rows("PRAGMA table_info(revlog)") { row in
                let name = Self.text(row, 1)
                columns[name.lowercased()] = name
            }
            func column(_ alternatives: String...) -> String? {
                alternatives.compactMap { columns[$0.lowercased()] }.first.map { "\"\($0)\"" }
            }
            guard let id = column("id"), let cid = column("cid", "card_id") else {
                throw AnkiImportError.invalid("таблица revlog не содержит идентификаторы review/card")
            }
            let usn = column("usn", "update_sequence_number") ?? "0"
            let ease = column("ease", "button_chosen", "rating") ?? "0"
            let interval = column("ivl", "interval") ?? "0"
            let previousInterval = column("lastIvl", "last_ivl", "last_interval") ?? "0"
            let factor = column("factor", "ease_factor") ?? "0"
            let time = column("time", "taken_millis", "answer_time_milliseconds") ?? "0"
            let type = column("type", "review_kind", "kind") ?? "0"
            var count = 0
            // Do not ORDER BY here. Large collections may require a temporary
            // SQLite file, which is unavailable for some security-scoped imports.
            // Group in one pass and sort only each card's history in memory.
            try rows("SELECT \(id), \(cid), \(usn), \(ease), \(interval), \(previousInterval), \(factor), \(time), \(type) FROM revlog") { row in
                guard count < 5_000_000 else { throw AnkiImportError.limit }
                count += 1
                let entry = AnkiReviewLogEntry(
                    id: sqlite3_column_int64(row, 0), cardID: sqlite3_column_int64(row, 1),
                    updateSequenceNumber: sqlite3_column_int64(row, 2), ease: Int(sqlite3_column_int64(row, 3)),
                    interval: sqlite3_column_int64(row, 4), previousInterval: sqlite3_column_int64(row, 5),
                    factor: sqlite3_column_int64(row, 6), answerTimeMilliseconds: sqlite3_column_int64(row, 7),
                    type: Int(sqlite3_column_int64(row, 8)))
                historyByCard[entry.cardID, default: []].append(entry)
            }
            for index in cards.indices {
                cards[index].reviewHistory = (historyByCard[cards[index].id] ?? []).sorted { $0.id < $1.id }
            }
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
        return AnkiCollection(decks: decks, noteTypes: models, notes: notes, cards: cards, creationTime: creationTime)
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
