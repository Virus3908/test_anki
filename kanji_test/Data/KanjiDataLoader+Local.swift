import Foundation

extension KanjiDataLoader {
    static func loadBundledMasterCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji-all", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([KanjiCard].self, from: data)
        } catch {
            assertionFailure("Failed to decode kanji-all.json: \(error)")
            return []
        }
    }

    static func loadAvailableCards(deck: KanjiDeck) -> [KanjiCard] {
        let masterCards = loadBundledMasterCards()
        let masterDeckCards = masterCards.filter(deck.masterFilter)
        if !masterDeckCards.isEmpty {
            return TranslationRepository.apply(to: masterDeckCards)
        }

        if deck != .all, let allCachedCards = try? KanjiDeckCacheRepository.loadCards(for: .all), !allCachedCards.isEmpty {
            let filteredCards = allCachedCards.filter(deck.masterFilter)
            if !filteredCards.isEmpty {
                return prepareLoadedCards(filteredCards)
            }
        }

        if let cachedCards = try? KanjiDeckCacheRepository.loadCards(for: deck), !cachedCards.isEmpty {
            return prepareLoadedCards(cachedCards)
        }

        return []
    }

    static func loadLocalCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji-data", withExtension: "json") else {
            assertionFailure("kanji-data.json is missing from the app bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return TranslationRepository.apply(to: try JSONDecoder().decode([KanjiCard].self, from: data))
        } catch {
            assertionFailure("Failed to decode kanji-data.json: \(error)")
            return []
        }
    }

    static func prepareLoadedCards(_ cards: [KanjiCard]) -> [KanjiCard] {
        TranslationRepository.migrateKanjiTranslations(from: cards)
        return TranslationRepository.apply(to: cards)
    }
}
