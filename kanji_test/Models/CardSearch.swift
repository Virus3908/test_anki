import Foundation

/// Одна карточка в поисковом индексе.
///
/// Запись сама решает, по каким строкам её можно найти: например, кандзи
/// ищется по символу, значениям и чтениям в обеих письменностях (кана и
/// ромадзи). Индекс только хранит эти строки и сравнивает их с запросом.
protocol CardSearchRecord: Sendable {
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
struct CardSearchIndex<Record: CardSearchRecord>: Sendable {
    private let prepared: [Prepared]

    /// Нормализованные строки одной записи, собранные в одну строку для
    /// быстрого `contains`. Термы разделяются пробелом (пробел не встречается
    /// внутри нормализованных термов, потому что запрос делится по пробелам).
    private struct Prepared {
        let record: Record
        let haystack: String
    }

    init(records: [Record]) {
        prepared = records.map { record in
            let joined = record.searchTerms.joined(separator: " ").lowercased()
            return Prepared(record: record, haystack: joined)
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
        let words = rawQuery
            .lowercased()
            .split(separator: " ")
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return [] }

        return prepared.compactMap { entry in
            let matches = words.allSatisfy { word in
                entry.haystack.range(of: word) != nil
            }
            return matches ? entry.record : nil
        }
    }
}

/// Кандзи в поиске: символ, значения (англ. и рус.), чтения (кана и ромадзи).
///
/// Рус. значения передаются снаружи: в данных их нет — они живут в
/// сохранённых переводах, поэтому их приносит с собой тот, кто строит индекс.
struct KanjiSearchRecord: CardSearchRecord {
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
struct WordSearchRecord: CardSearchRecord {
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
