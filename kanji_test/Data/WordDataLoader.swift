import Foundation

enum WordDataLoader {
    static func loadWords() async -> [WordStudyCard] {
        await loadWords(in: nil)
    }

    static func loadWords(for deck: WordFrequencyDeck) async -> [WordStudyCard] {
        await loadWords(in: deck.bounds)
    }

    private static func loadWords(in range: Range<Int>?) async -> [WordStudyCard] {
        await Task.yield()

        let allEntries = await loadDictionaryEntries()
        let entries: [WordDictionaryEntry]
        if let range {
            entries = Array(allEntries[range.clamped(to: allEntries.indices)])
        } else {
            entries = allEntries
        }
        let kanjiCards = await loadKanjiCards(for: entries, provider: KanjiAPIProvider())
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        let loadedWords = buildWords(from: entries, cardsByCharacter: cardsByCharacter)

        if !loadedWords.isEmpty {
            return loadedWords
        }

        return WordStudyCard.build(from: kanjiCards)
    }
}
