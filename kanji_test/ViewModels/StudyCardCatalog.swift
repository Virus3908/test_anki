import Foundation
import Observation

@MainActor
@Observable
final class StudyCardCatalog {
    private var kanjiByID: [String: KanjiCard] = [:]
    private var wordsByID: [String: WordRecord] = [:]
    private var kanaByID: [String: KanaStudyCard] = [:]
    private var ankiByID: [String: AnkiStudyCard] = [:]

    private struct WordRecord {
        let word: String
        let reading: String
        let meaning: String
        let examples: [WordUsageExample]
        let characterIDs: [String]
    }

    func kanji(_ id: String) -> KanjiCard? { kanjiByID[id] }
    func kana(_ id: String) -> KanaStudyCard? { kanaByID[id] }
    func anki(_ id: String) -> AnkiStudyCard? { ankiByID[id] }

    @discardableResult
    func register(_ cards: [AnkiStudyCard]) -> [String] {
        for card in cards { ankiByID[card.id] = card }
        return cards.map(\.id)
    }
    func word(_ id: String) -> WordStudyCard? {
        guard let record = wordsByID[id] else { return nil }
        return WordStudyCard(word: record.word, reading: record.reading, meaning: record.meaning,
                             examples: record.examples, kanjiCards: record.characterIDs.compactMap { kanjiByID[$0] })
    }

    @discardableResult
    func register(_ cards: [KanjiCard]) -> [String] {
        for original in cards {
            let card = original.withoutTranslations
            if let existing = kanjiByID[card.id] {
                // Assigning a queue snapshot must not overwrite newer canonical card data.
                if existing.strokes.isEmpty && !card.strokes.isEmpty {
                    kanjiByID[card.id] = existing.mergedForDisplay(with: card)
                }
            } else { kanjiByID[card.id] = card }
        }
        return cards.map(\.id)
    }

    @discardableResult
    func register(_ cards: [WordStudyCard]) -> [String] {
        for card in cards {
            wordsByID[card.id] = WordRecord(word: card.word, reading: card.reading, meaning: card.meaning,
                examples: card.examples, characterIDs: register(card.kanjiCards))
        }
        return cards.map(\.id)
    }

    @discardableResult
    func register(_ cards: [KanaStudyCard]) -> [String] {
        for card in cards { kanaByID[card.id] = card }
        return cards.map(\.id)
    }

    func update(_ card: KanjiCard) {
        kanjiByID[card.id] = card.withoutTranslations
    }

    func clear() {
        kanjiByID.removeAll()
        wordsByID.removeAll()
        kanaByID.removeAll()
        ankiByID.removeAll()
    }
}
