import Foundation

extension KanjiDataLoader {
    static func loadBundledMasterCards() async -> [KanjiCard] {
        (try? await BundledStudyData.shared.kanjiCards(resource: "kanji-all")) ?? []
    }

    static func loadAvailableCards(deck: KanjiDeck, cache: KanjiDeckCacheRepository = .shared) async -> [KanjiCard] {
        let masterCards = await loadBundledMasterCards()
        let cachedCards = (try? await cache.loadCards(for: .all)) ?? []
        // Downloaded resources augment the bundle instead of being hidden by it.
        var cards = Dictionary(masterCards.map { ($0.kanji, $0) }, uniquingKeysWith: { first, _ in first })
        for card in cachedCards { cards[card.kanji] = card }
        let filtered = cards.values.filter(deck.masterFilter).sorted { $0.kanji < $1.kanji }
        if !filtered.isEmpty { return filtered.map(\.withoutTranslations) }
        if let cached = try? await cache.loadCards(for: deck), !cached.isEmpty {
            return await prepareLoadedCards(cached)
        }
        return []
    }

    static func loadLocalCards() async -> [KanjiCard] {
        let cards = (try? await BundledStudyData.shared.kanjiCards(resource: "kanji-data")) ?? []
        return cards.map(\.withoutTranslations)
    }

    static func prepareLoadedCards(_ cards: [KanjiCard]) async -> [KanjiCard] {
        return cards.map(\.withoutTranslations)
    }
}
