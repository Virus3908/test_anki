import Foundation

enum KanjiDeckCacheRepository {
    static func loadCards(for deck: KanjiDeck) throws -> [KanjiCard]? {
        let url = cacheURL(for: deck)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([KanjiCard].self, from: data)
    }

    static func mergeCardsIntoAllCache(_ cards: [KanjiCard]) throws {
        guard !cards.isEmpty else {
            return
        }

        let existingCards = (try? loadCards(for: .all)) ?? []
        var cardsByKanji = Dictionary(existingCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })

        for card in cards {
            if let existingCard = cardsByKanji[card.kanji] {
                cardsByKanji[card.kanji] = mergeCachedCard(existingCard, with: card)
            } else {
                cardsByKanji[card.kanji] = card
            }
        }

        try saveCards(cardsByKanji.values.sorted { $0.kanji < $1.kanji }, for: .all)
    }

    static func clearCache() throws {
        let directory = cacheDirectoryURL()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)
    }

    static func mergeCachedCard(_ cached: KanjiCard, with fresh: KanjiCard) -> KanjiCard {
        KanjiCard(
            kanji: fresh.kanji,
            meanings: fresh.englishMeanings,
            onyomi: fresh.onyomi,
            kunyomi: fresh.kunyomi,
            examples: fresh.englishExamples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: nil,
            russianExamples: nil,
            source: fresh.source,
            strokes: fresh.strokes,
            grade: fresh.grade,
            jlpt: fresh.jlpt,
            translationState: nil
        )
    }

    private static func saveCards(_ cards: [KanjiCard], for deck: KanjiDeck) throws {
        let url = cacheURL(for: deck)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(cards.map(\.withoutTranslations))
        try data.write(to: url, options: .atomic)
    }

    private static func cacheURL(for deck: KanjiDeck) -> URL {
        cacheDirectoryURL()
            .appendingPathComponent("\(deck.rawValue).json")
    }

    private static func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanjiDeckCacheV2", isDirectory: true)
    }
}
