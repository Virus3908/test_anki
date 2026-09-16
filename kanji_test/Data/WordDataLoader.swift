import Foundation

enum WordDataLoader {
    static func loadWords() async -> [WordStudyCard] {
        await Task.yield()

        let entries = await loadDictionaryEntries()
        let kanjiCards = await loadKanjiCards(for: entries, provider: KanjiAPIProvider())
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        let loadedWords = buildWords(from: entries, cardsByCharacter: cardsByCharacter)

        if !loadedWords.isEmpty {
            return loadedWords
        }

        return WordStudyCard.build(from: kanjiCards)
    }
}
