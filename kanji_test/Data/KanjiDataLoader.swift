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
            return KanjiTranslationStore.apply(to: masterDeckCards)
        }

        if deck != .all, let allCachedCards = try? loadCachedCards(for: .all), !allCachedCards.isEmpty {
            let filteredCards = allCachedCards.filter(deck.masterFilter)
            if !filteredCards.isEmpty {
                return prepareLoadedCards(filteredCards)
            }
        }

        if let cachedCards = try? loadCachedCards(for: deck), !cachedCards.isEmpty {
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
            return KanjiTranslationStore.apply(to: try JSONDecoder().decode([KanjiCard].self, from: data))
        } catch {
            assertionFailure("Failed to decode kanji-data.json: \(error)")
            return []
        }
    }

    static func loadCards(deck: KanjiDeck = .jlpt5) async -> [KanjiCard] {
        let availableCards = loadAvailableCards(deck: deck)
        if !availableCards.isEmpty {
            return availableCards
        }

        do {
            let cachedCards = try loadCachedCards(for: deck) ?? []
            let remoteKanjiList = try await RemoteKanjiProvider.loadKanjiList(deck: deck)

            if !cachedCards.isEmpty {
                let cachedByKanji = Dictionary(cachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
                let missingKanji = remoteKanjiList.filter { cachedByKanji[$0] == nil }

                if missingKanji.isEmpty {
                    return prepareLoadedCards(remoteKanjiList.compactMap { cachedByKanji[$0] })
                }

                let missingCards = try await RemoteKanjiProvider.loadCards(for: missingKanji)
                let mergedByKanji = Dictionary((cachedCards + missingCards).map { ($0.kanji, $0) }, uniquingKeysWith: { current, new in
                    mergeCachedCard(current, with: new)
                })
                let mergedCards = remoteKanjiList.compactMap { mergedByKanji[$0] }

                if !mergedCards.isEmpty {
                    try mergeCardsIntoAllCache(mergedCards)
                    return KanjiTranslationStore.apply(to: mergedCards)
                }
            }

            let remoteCards = try await RemoteKanjiProvider.loadCards(for: remoteKanjiList)
            if !remoteCards.isEmpty {
                try mergeCardsIntoAllCache(remoteCards)
                return KanjiTranslationStore.apply(to: remoteCards)
            }
        } catch {
            if let cachedCards = try? loadCachedCards(for: deck), !cachedCards.isEmpty {
                return prepareLoadedCards(cachedCards)
            }

            assertionFailure("Failed to load remote kanji data: \(error)")
        }

        return loadLocalCards()
    }

    static func loadCardsProgressively(
        deck: KanjiDeck,
        onUpdate: @MainActor @escaping ([KanjiCard], Int?) -> Void
    ) async {
        let bundledOrCachedCards = loadAvailableCards(deck: deck)
        if !bundledOrCachedCards.isEmpty {
            onUpdate(bundledOrCachedCards, bundledOrCachedCards.count)
        }

        do {
            let remoteKanjiList = try await RemoteKanjiProvider.loadKanjiList(deck: deck)
            var cardsByKanji = Dictionary(bundledOrCachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
            let missingKanji = remoteKanjiList.filter { cardsByKanji[$0] == nil }

            if missingKanji.isEmpty {
                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(KanjiTranslationStore.apply(to: orderedCards), remoteKanjiList.count)
                return
            }

            for await batch in RemoteKanjiProvider.loadCardsStream(for: missingKanji) {
                for card in batch {
                    if let existingCard = cardsByKanji[card.kanji] {
                        cardsByKanji[card.kanji] = mergeCachedCard(existingCard, with: card)
                    } else {
                        cardsByKanji[card.kanji] = card
                    }
                }

                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(KanjiTranslationStore.apply(to: orderedCards), remoteKanjiList.count)
            }

            let finalCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
            if !finalCards.isEmpty {
                try mergeCardsIntoAllCache(finalCards)
                onUpdate(KanjiTranslationStore.apply(to: finalCards), remoteKanjiList.count)
            }
        } catch {
            if bundledOrCachedCards.isEmpty {
                onUpdate(loadLocalCards(), nil)
            }
        }
    }

    static func cacheCards(_ cards: [KanjiCard]) {
        do {
            try mergeCardsIntoAllCache(cards)
        } catch {
            assertionFailure("Failed to cache kanji cards: \(error)")
        }
    }

    static func clearCache() {
        do {
            let directory = cacheDirectoryURL()
            guard FileManager.default.fileExists(atPath: directory.path) else {
                return
            }

            try FileManager.default.removeItem(at: directory)
        } catch {
            assertionFailure("Failed to clear kanji deck cache: \(error)")
        }
    }

    static func translateMeaningsIfNeeded(_ card: KanjiCard, deck: KanjiDeck, force: Bool = false) async -> KanjiCard {
        guard force || !card.hasRussianMeanings else {
            return card
        }

        let meanings = await RussianMeaningTranslator.translate(card.englishMeanings)
        let translatedCard = card.withRussianMeanings(meanings)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    static func translateExamplesIfNeeded(_ card: KanjiCard, deck: KanjiDeck, force: Bool = false) async -> KanjiCard {
        guard force || !card.hasRussianExamples else {
            return card
        }

        let sourceExamples = card.englishExamples
        let translatedExampleMeanings = await RussianMeaningTranslator.translatePreservingOrder(sourceExamples.map(\.meaning))
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
        KanjiTranslationStore.saveKanjiTranslation(from: card)
    }

    private static func prepareLoadedCards(_ cards: [KanjiCard]) -> [KanjiCard] {
        KanjiTranslationStore.migrateKanjiTranslations(from: cards)
        return KanjiTranslationStore.apply(to: cards)
    }

    private static func loadCachedCards(for deck: KanjiDeck) throws -> [KanjiCard]? {
        let url = cacheURL(for: deck)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([KanjiCard].self, from: data)
    }

    private static func saveCachedCards(_ cards: [KanjiCard], for deck: KanjiDeck) throws {
        let url = cacheURL(for: deck)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(cards.map(\.withoutTranslations))
        try data.write(to: url, options: .atomic)
    }

    private static func updateCachedCard(_ card: KanjiCard, for deck: KanjiDeck) throws {
        let cacheDeck = deck == .all ? deck : .all
        guard var cachedCards = try loadCachedCards(for: cacheDeck) else {
            try saveCachedCards([card], for: cacheDeck)
            return
        }

        if let index = cachedCards.firstIndex(where: { $0.kanji == card.kanji }) {
            cachedCards[index] = mergeCachedCard(cachedCards[index], with: card)
        } else {
            cachedCards.append(card)
        }

        try saveCachedCards(cachedCards, for: cacheDeck)
    }

    private static func mergeCardsIntoAllCache(_ cards: [KanjiCard]) throws {
        guard !cards.isEmpty else {
            return
        }

        let existingCards = (try? loadCachedCards(for: .all)) ?? []
        var cardsByKanji = Dictionary(existingCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })

        for card in cards {
            if let existingCard = cardsByKanji[card.kanji] {
                cardsByKanji[card.kanji] = mergeCachedCard(existingCard, with: card)
            } else {
                cardsByKanji[card.kanji] = card
            }
        }

        try saveCachedCards(cardsByKanji.values.sorted { $0.kanji < $1.kanji }, for: .all)
    }

    private static func mergeCachedCard(_ cached: KanjiCard, with fresh: KanjiCard) -> KanjiCard {
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

    private static func cacheURL(for deck: KanjiDeck) -> URL {
        cacheDirectoryURL()
            .appendingPathComponent("\(deck.rawValue).json")
    }

    private static func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanjiDeckCacheV2", isDirectory: true)
    }
}
