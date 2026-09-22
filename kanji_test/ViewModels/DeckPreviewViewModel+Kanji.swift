import Foundation

extension DeckPreviewViewModel {
    func openKanjiPreview(_ deck: KanjiDeck) {
        cancelPreviewTask()
        navigation.open(.kanjiDeck(deck))
        loadError = nil
        previewWordCards.removeAll()
        previewKanaCards.removeAll()
        previewCards.removeAll()
        previewExpectedCount = nil
        isLoadingDeck = true

        let requestID = previewRequestID
        let provider = kanjiProvider
        deckPreviewTask = Task { [weak self] in
            await KanjiDataLoader.loadCardsProgressively(deck: deck, provider: provider) { loadedCards, expectedCount in
                self?.applyKanjiPreviewUpdate(
                    loadedCards,
                    expectedCount: expectedCount,
                    deck: deck,
                    requestID: requestID
                )
            }

            self?.finishKanjiPreviewLoad(for: deck, requestID: requestID)
        }
    }

    func closeKanjiPreview() {
        cancelPreviewTask()
        navigation.open(.start)
        previewCards.removeAll()
        previewExpectedCount = nil
        isLoadingDeck = false
    }

    private func applyKanjiPreviewUpdate(
        _ loadedCards: [KanjiCard],
        expectedCount: Int?,
        deck: KanjiDeck,
        requestID: UUID
    ) {
        guard previewDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
            return
        }

        previewCards = uniqueCards(loadedCards)
        previewExpectedCount = expectedCount
        isLoadingDeck = previewExpectedCount.map { previewCards.count < $0 } ?? false
    }

    private func uniqueCards(_ cards: [KanjiCard]) -> [KanjiCard] {
        var indexesByKanji: [String: Int] = [:]
        var uniqueCards: [KanjiCard] = []
        for card in cards {
            if let index = indexesByKanji[card.kanji] {
                uniqueCards[index] = uniqueCards[index].mergedForDisplay(with: card)
            } else {
                indexesByKanji[card.kanji] = uniqueCards.count
                uniqueCards.append(card)
            }
        }

        return uniqueCards
    }

    private func finishKanjiPreviewLoad(for deck: KanjiDeck, requestID: UUID) {
        guard previewDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
            return
        }

        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
