import Foundation
import AnkiImport

/// Одна карточка в поисковом индексе.
///
/// Запись сама решает, по каким строкам её можно найти: например, кандзи
/// ищется по символу, значениям и чтениям в обеих письменностях (кана и
/// ромадзи). Индекс только хранит эти строки и сравнивает их с запросом.
nonisolated protocol CardSearchRecord: Sendable {
    /// Нормализованные (lowercase) строки, по которым находится запись.
    var searchTerms: [String] { get }
}

/// Неизменяемый поисковый индекс по заранее заданному набору записей.
///
///     let index = CardSearchIndex(records: records)
///     let found = index.search("kuchi")
///
/// Подготовка (`searchTerms`) выполняется один раз при создании; сам поиск —
/// линейный проход без аллокаций на каждый запрос.
nonisolated struct CardSearchIndex<Record: CardSearchRecord>: Sendable {
    private let prepared: [Prepared]

    /// Нормализованные строки одной записи, собранные в одну строку для
    /// быстрого `contains`. Термы разделяются пробелом (пробел не встречается
    /// внутри нормализованных термов, потому что запрос делится по пробелам).
    nonisolated private struct Prepared {
        let record: Record
        let haystack: String
    }

    init(records: [Record]) {
        prepared = records.map { record in
            let joined = record.searchTerms.joined(separator: " ").lowercased()
            return Prepared(record: record, haystack: joined)
        }
    }

    /// Вариант для фоновой нормализации уже извлечённых поисковых термов.
    nonisolated init(records: [Record], haystacks: [String]) {
        prepared = zip(records, haystacks).map { record, haystack in
            Prepared(record: record, haystack: haystack)
        }
    }

    /// Количество записей в индексе.
    var count: Int { prepared.count }

    /// Находит записи, подходящие под запрос.
    ///
    /// Запрос делится на слова по пробелам; записью подходит та, у которой
    /// КАЖДОЕ слово содержится в каком-нибудь её терме (пересечение по AND).
    /// Порядок результата — порядок записей в индексе.
    func search(_ rawQuery: String) -> [Record] {
        (try? search(rawQuery, limit: .max).records) ?? []
    }

    /// Count every match but retain only the visible prefix. Cancellation is
    /// checked during the scan so an obsolete query releases the worker promptly.
    func search(_ rawQuery: String, limit: Int) throws -> CardSearchMatches<Record> {
        let words = rawQuery.lowercased().split(separator: " ")
        guard !words.isEmpty else { return CardSearchMatches(records: [], totalFound: 0) }
        var records: [Record] = []
        var total = 0
        for (offset, entry) in prepared.enumerated() {
            if offset.isMultiple(of: 128) { try Task.checkCancellation() }
            if words.allSatisfy({ entry.haystack.range(of: $0) != nil }) {
                total += 1
                if records.count < max(0, limit) { records.append(entry.record) }
            }
        }
        try Task.checkCancellation()
        return CardSearchMatches(records: records, totalFound: total)
    }

}

/// Кандзи в поиске: символ, значения (англ. и рус.), чтения (кана и ромадзи).
///
/// Рус. значения передаются снаружи: в данных их нет — они живут в
/// сохранённых переводах, поэтому их приносит с собой тот, кто строит индекс.
nonisolated struct KanjiSearchRecord: CardSearchRecord {
    let card: KanjiCard
    let russianMeanings: [String]

    init(card: KanjiCard, russianMeanings: [String]) {
        self.card = card
        self.russianMeanings = russianMeanings
    }

    var searchTerms: [String] {
        var terms: [String] = [card.kanji]
        terms.append(contentsOf: card.meanings)
        terms.append(contentsOf: russianMeanings)

        // Чтения — в обеих письменностях: くち и kuchi.
        for reading in card.kunyomi + card.onyomi {
            terms.append(reading)
            let romaji = KanaRomaji.convert(reading)
            if !romaji.isEmpty {
                terms.append(romaji)
                // Долгие гласные часто набирают кратко: こう → "ko".
                terms.append(KanaRomaji.compact(romaji))
            }
        }

        return terms
    }
}

/// Слово в поиске: само слово, чтение (кана и ромадзи), значение.
/// Рус. переводов для слов в данных нет — значение только английское.
nonisolated struct WordSearchRecord: CardSearchRecord {
    let entry: WordDictionaryEntry

    init(entry: WordDictionaryEntry) {
        self.entry = entry
    }

    var searchTerms: [String] {
        var terms: [String] = [entry.word, entry.reading, entry.meaning]

        let romaji = KanaRomaji.convert(entry.reading)
        if !romaji.isEmpty {
            terms.append(romaji)
            terms.append(KanaRomaji.compact(romaji))
        }

        return terms
    }
}

/// Кана в поиске: знак и его чтение в ромадзи.
nonisolated struct KanaSearchRecord: CardSearchRecord {
    let card: KanaStudyCard

    var searchTerms: [String] {
        [card.character, card.reading]
    }
}

/// Импортированная карточка Anki ищется по содержимому всех полей, тегам,
/// названию колоды, типу заметки и шаблону карточки.
nonisolated struct AnkiSearchRecord: CardSearchRecord, Codable, Identifiable {
    let importID: String
    let cardID: Int64
    let noteID: Int64
    let deckID: Int64
    let noteTypeID: Int64
    let deckName: String
    let titleFields: [String]
    let text: String
    var id: String { "\(importID):card:\(cardID)" }
    var fieldPreferencesKey: String { "\(importID):\(deckID):\(noteTypeID)" }
    var searchTerms: [String] { [text] }

    func displayTitle(using options: AnkiFieldDisplayOptions) -> String {
        let title = titleFields[safe: options.titleOrdinal] ?? ""
        return title.isEmpty ? "Карточка \(cardID)" : title
    }

    static func records(collection: AnkiCollection, importID: String, filename: String) throws -> [Self] {
        let notes = Dictionary(collection.notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let types = Dictionary(collection.noteTypes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let decks = Dictionary(collection.decks.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return try collection.cards.map { card -> Self? in
            try Task.checkCancellation()
            guard let note = notes[card.noteID], let type = types[note.noteTypeID] else { return nil }
            let fields = note.parsedFields?.map(\.plainText) ?? note.fields
            let deck = decks[card.deckID] ?? filename
            let template = type.isCloze ? "Пропуск \(card.ordinal + 1)"
                : type.templates.first(where: { $0.ordinal == card.ordinal })?.name ?? type.name
            return Self(importID: importID, cardID: card.id, noteID: note.id,
                deckID: card.deckID, noteTypeID: type.id, deckName: deck,
                titleFields: fields.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)) },
                text: (fields + note.tags + [deck, type.name, template]).joined(separator: " ").lowercased())
        }.compactMap { $0 }
    }
}

nonisolated struct CardSearchMatches<Record: Sendable>: Sendable {
    let records: [Record]
    let totalFound: Int
}
