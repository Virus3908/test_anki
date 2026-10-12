import Foundation

actor KanjiDeckCacheRepository {
    static let shared = KanjiDeckCacheRepository()
    private let byteLimit = 32 * 1024 * 1024
    private var decodedDecks: [KanjiDeck: [KanjiCard]] = [:]

    func loadCards(for deck: KanjiDeck) throws -> [KanjiCard]? {
        if let cached = decodedDecks[deck] { return cached }
        let url = cacheURL(for: deck)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        if (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > byteLimit {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        let cards: [KanjiCard]
        do { cards = try JSONDecoder().decode([KanjiCard].self, from: Data(contentsOf: url)) }
        catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        retain(cards, for: deck)
        return cards
    }

    func mergeCardsIntoAllCache(_ cards: [KanjiCard]) throws {
        try Task.checkCancellation()
        guard !cards.isEmpty else {
            return
        }

        let existingCards = (try? loadCards(for: .all)) ?? []
        var cardsByKanji = Dictionary(existingCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })

        for card in cards {
            if let existingCard = cardsByKanji[card.kanji] {
                cardsByKanji[card.kanji] = Self.mergeCachedCard(existingCard, with: card)
            } else {
                cardsByKanji[card.kanji] = card
            }
        }

        try saveCards(cardsByKanji.values.sorted { $0.kanji < $1.kanji }, for: .all)
    }

    func clearCache() throws {
        decodedDecks.removeAll()
        let directory = cacheDirectoryURL()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)
    }

    nonisolated static func mergeCachedCard(_ cached: KanjiCard, with fresh: KanjiCard) -> KanjiCard {
        cached.mergedForDisplay(with: fresh)
    }

    private func saveCards(_ cards: [KanjiCard], for deck: KanjiDeck) throws {
        let url = cacheURL(for: deck)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let normalized = cards.map(\.withoutTranslations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(normalized)
        guard data.count <= byteLimit else {
            decodedDecks[deck] = nil
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        if let existing = try? Data(contentsOf: url),
           let old = try? JSONDecoder().decode([KanjiCard].self, from: existing),
           try encoder.encode(old) == data {
            retain(normalized, for: deck)
            return
        }
        try data.write(to: url, options: .atomic)
        retain(normalized, for: deck)
    }

    private func retain(_ cards: [KanjiCard], for deck: KanjiDeck) {
        if decodedDecks[deck] == nil, decodedDecks.count >= 3,
           let evicted = decodedDecks.keys.sorted(by: { $0.rawValue < $1.rawValue }).first {
            decodedDecks[evicted] = nil
        }
        decodedDecks[deck] = cards
    }

    private func cacheURL(for deck: KanjiDeck) -> URL {
        cacheDirectoryURL()
            .appendingPathComponent("\(deck.rawValue).json")
    }

    private func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanjiDeckCacheV2", isDirectory: true)
    }
}
