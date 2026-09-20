import Foundation

enum WordDataLoader {
    static func loadWords(provider: any KanjiProviding = KanjiAPIProvider()) async throws -> [WordStudyCard] {
        try await loadWords(in: nil, provider: provider)
    }

    static func loadWords(for deck: WordFrequencyDeck, provider: any KanjiProviding = KanjiAPIProvider()) async throws -> [WordStudyCard] {
        try await loadWords(in: deck.bounds, provider: provider)
    }

    static func loadWords(
        containing kanji: String,
        limit: Int = 3,
        provider: any KanjiProviding = KanjiAPIProvider()
    ) async throws -> [WordStudyCard] {
        let entries = try await loadDictionaryEntries()
        let matchingEntries = Array(entries.lazy.filter { $0.word.contains(kanji) }.prefix(limit))
        let kanjiCards = await loadKanjiCards(for: matchingEntries, provider: provider)
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })

        try Task.checkCancellation()
        return buildWords(from: matchingEntries, cardsByCharacter: cardsByCharacter)
    }

    private static func loadWords(in range: Range<Int>?, provider: any KanjiProviding) async throws -> [WordStudyCard] {
        let allEntries = try await loadDictionaryEntries()
        let entries: [WordDictionaryEntry]
        if let range {
            entries = Array(allEntries[range.clamped(to: allEntries.indices)])
        } else {
            entries = allEntries
        }
        let kanjiCards = await loadKanjiCards(for: entries, provider: provider)
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        let loadedWords = buildWords(from: entries, cardsByCharacter: cardsByCharacter)

        try Task.checkCancellation()
        return loadedWords
    }
}
