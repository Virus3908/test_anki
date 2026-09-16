import Foundation

enum KanjiDataLoader {
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

    static func loadCards(deck: KanjiDeck = .jlpt5, provider: KanjiProviding = KanjiAPIProvider()) async -> [KanjiCard] {
        let availableCards = loadAvailableCards(deck: deck)
        if !availableCards.isEmpty {
            return availableCards
        }

        do {
            let cachedCards = try KanjiDeckCacheRepository.loadCards(for: deck) ?? []
            let remoteKanjiList = try await provider.loadKanjiList(deck: deck)

            if !cachedCards.isEmpty {
                let cachedByKanji = Dictionary(cachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
                let missingKanji = remoteKanjiList.filter { cachedByKanji[$0] == nil }

                if missingKanji.isEmpty {
                    return prepareLoadedCards(remoteKanjiList.compactMap { cachedByKanji[$0] })
                }

                let missingCards = try await provider.loadCards(for: missingKanji)
                let mergedByKanji = Dictionary((cachedCards + missingCards).map { ($0.kanji, $0) }, uniquingKeysWith: { current, new in
                    KanjiDeckCacheRepository.mergeCachedCard(current, with: new)
                })
                let mergedCards = remoteKanjiList.compactMap { mergedByKanji[$0] }

                if !mergedCards.isEmpty {
                    try KanjiDeckCacheRepository.mergeCardsIntoAllCache(mergedCards)
                    return TranslationRepository.apply(to: mergedCards)
                }
            }

            let remoteCards = try await provider.loadCards(for: remoteKanjiList)
            if !remoteCards.isEmpty {
                try KanjiDeckCacheRepository.mergeCardsIntoAllCache(remoteCards)
                return TranslationRepository.apply(to: remoteCards)
            }
        } catch {
            if let cachedCards = try? KanjiDeckCacheRepository.loadCards(for: deck), !cachedCards.isEmpty {
                return prepareLoadedCards(cachedCards)
            }

            assertionFailure("Failed to load remote kanji data: \(error)")
        }

        return loadLocalCards()
    }

    static func loadCardsProgressively(
        deck: KanjiDeck,
        provider: KanjiProviding = KanjiAPIProvider(),
        onUpdate: @MainActor @escaping ([KanjiCard], Int?) -> Void
    ) async {
        let bundledOrCachedCards = loadAvailableCards(deck: deck)
        if !bundledOrCachedCards.isEmpty {
            onUpdate(bundledOrCachedCards, bundledOrCachedCards.count)
        }

        do {
            let remoteKanjiList = try await provider.loadKanjiList(deck: deck)
            var cardsByKanji = Dictionary(bundledOrCachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
            let missingKanji = remoteKanjiList.filter { cardsByKanji[$0] == nil }

            if missingKanji.isEmpty {
                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(TranslationRepository.apply(to: orderedCards), remoteKanjiList.count)
                return
            }

            for await batch in provider.loadCardsStream(for: missingKanji) {
                for card in batch {
                    if let existingCard = cardsByKanji[card.kanji] {
                        cardsByKanji[card.kanji] = KanjiDeckCacheRepository.mergeCachedCard(existingCard, with: card)
                    } else {
                        cardsByKanji[card.kanji] = card
                    }
                }

                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(TranslationRepository.apply(to: orderedCards), remoteKanjiList.count)
            }

            let finalCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
            if !finalCards.isEmpty {
                try KanjiDeckCacheRepository.mergeCardsIntoAllCache(finalCards)
                onUpdate(TranslationRepository.apply(to: finalCards), remoteKanjiList.count)
            }
        } catch {
            if bundledOrCachedCards.isEmpty {
                onUpdate(loadLocalCards(), nil)
            }
        }
    }

    static func cacheCards(_ cards: [KanjiCard]) {
        do {
            try KanjiDeckCacheRepository.mergeCardsIntoAllCache(cards)
        } catch {
            assertionFailure("Failed to cache kanji cards: \(error)")
        }
    }

    static func clearCache() {
        do {
            try KanjiDeckCacheRepository.clearCache()
        } catch {
            assertionFailure("Failed to clear kanji deck cache: \(error)")
        }
    }

    static func translateMeaningsIfNeeded(
        _ card: KanjiCard,
        deck: KanjiDeck,
        force: Bool = false,
        translator: MeaningTranslating = SystemRussianMeaningTranslator()
    ) async -> KanjiCard {
        guard force || !card.hasRussianMeanings else {
            return card
        }

        let meanings = await translator.translate(card.englishMeanings)
        let translatedCard = card.withRussianMeanings(meanings)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    static func translateExamplesIfNeeded(
        _ card: KanjiCard,
        deck: KanjiDeck,
        force: Bool = false,
        translator: MeaningTranslating = SystemRussianMeaningTranslator()
    ) async -> KanjiCard {
        guard force || !card.hasRussianExamples else {
            return card
        }

        let sourceExamples = card.englishExamples
        let translatedExampleMeanings = await translator.translatePreservingOrder(sourceExamples.map(\.meaning))
        let examples = sourceExamples.enumerated().map { index, example in
            KanjiExample(
                word: example.word,
                reading: example.reading,
                meaning: index < translatedExampleMeanings.count ? translatedExampleMeanings[index] : example.meaning
            )
        }
        let translatedCard = card.withRussianExamples(examples)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    private static func cacheTranslatedCard(_ card: KanjiCard, deck: KanjiDeck) {
        TranslationRepository.saveKanjiTranslation(from: card)
    }

    private static func prepareLoadedCards(_ cards: [KanjiCard]) -> [KanjiCard] {
        TranslationRepository.migrateKanjiTranslations(from: cards)
        return TranslationRepository.apply(to: cards)
    }

}
