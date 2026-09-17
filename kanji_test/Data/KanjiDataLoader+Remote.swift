import Foundation

extension KanjiDataLoader {
    static func loadCards(deck: KanjiDeck = .jlpt5, provider: KanjiProviding = KanjiAPIProvider()) async -> [KanjiCard] {
        let availableCards = await loadAvailableCards(deck: deck)
        if !availableCards.isEmpty {
            return availableCards
        }

        do {
            let cachedCards = try await KanjiDeckCacheRepository.shared.loadCards(for: deck) ?? []
            let remoteKanjiList = uniqueKanjiList(try await provider.loadKanjiList(deck: deck))

            if !cachedCards.isEmpty {
                let cachedByKanji = Dictionary(cachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
                let missingKanji = remoteKanjiList.filter { cachedByKanji[$0] == nil }

                if missingKanji.isEmpty {
                    return await prepareLoadedCards(remoteKanjiList.compactMap { cachedByKanji[$0] })
                }

                let missingCards = try await provider.loadCards(for: missingKanji)
                let mergedByKanji = Dictionary((cachedCards + missingCards).map { ($0.kanji, $0) }, uniquingKeysWith: { current, new in
                    KanjiDeckCacheRepository.mergeCachedCard(current, with: new)
                })
                let mergedCards = remoteKanjiList.compactMap { mergedByKanji[$0] }

                if !mergedCards.isEmpty {
                    try await KanjiDeckCacheRepository.shared.mergeCardsIntoAllCache(mergedCards)
                    return mergedCards.map(\.withoutTranslations)
                }
            }

            let remoteCards = try await provider.loadCards(for: remoteKanjiList)
            if !remoteCards.isEmpty {
                try await KanjiDeckCacheRepository.shared.mergeCardsIntoAllCache(remoteCards)
                return remoteCards.map(\.withoutTranslations)
            }
        } catch is CancellationError {
            return []
        } catch {
            if let cachedCards = try? await KanjiDeckCacheRepository.shared.loadCards(for: deck), !cachedCards.isEmpty {
                return await prepareLoadedCards(cachedCards)
            }

            if Task.isCancelled { return [] }
        }

        return await loadLocalCards()
    }

    static func loadCardsProgressively(
        deck: KanjiDeck,
        provider: KanjiProviding = KanjiAPIProvider(),
        onUpdate: @MainActor @escaping ([KanjiCard], Int?) -> Void
    ) async {
        let bundledOrCachedCards = await loadAvailableCards(deck: deck)
        if !bundledOrCachedCards.isEmpty {
            onUpdate(bundledOrCachedCards, bundledOrCachedCards.count)
        }

        do {
            let remoteKanjiList = uniqueKanjiList(try await provider.loadKanjiList(deck: deck))
            var cardsByKanji = Dictionary(bundledOrCachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
            let missingKanji = remoteKanjiList.filter { cardsByKanji[$0] == nil }

            if missingKanji.isEmpty {
                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(orderedCards.map(\.withoutTranslations), remoteKanjiList.count)
                return
            }

            for await batch in provider.loadCardsStream(for: missingKanji) {
                guard !Task.isCancelled else { return }
                for card in batch {
                    if let existingCard = cardsByKanji[card.kanji] {
                        cardsByKanji[card.kanji] = KanjiDeckCacheRepository.mergeCachedCard(existingCard, with: card)
                    } else {
                        cardsByKanji[card.kanji] = card
                    }
                }

                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(orderedCards.map(\.withoutTranslations), remoteKanjiList.count)
            }

            guard !Task.isCancelled else { return }
            let finalCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
            if !finalCards.isEmpty {
                try await KanjiDeckCacheRepository.shared.mergeCardsIntoAllCache(finalCards)
                onUpdate(finalCards.map(\.withoutTranslations), remoteKanjiList.count)
            }
        } catch {
            guard !Task.isCancelled else { return }
            if bundledOrCachedCards.isEmpty {
                onUpdate(await loadLocalCards(), nil)
            }
        }
    }

    static func uniqueKanjiList(_ kanjiList: [String]) -> [String] {
        var seen: Set<String> = []
        return kanjiList.filter { seen.insert($0).inserted }
    }

    static func cacheCards(_ cards: [KanjiCard]) async throws {
        try await KanjiDeckCacheRepository.shared.mergeCardsIntoAllCache(cards)
    }

    static func clearCache() async throws {
        try await KanjiDeckCacheRepository.shared.clearCache()
    }
}
