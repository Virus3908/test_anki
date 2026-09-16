import Foundation

extension DeckPreviewViewModel {
    func openKanjiPreview(_ deck: KanjiDeck, reviewStore: KanjiReviewStore) {
        cancelPreviewTask()
        previewDeck = deck
        previewKanaDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards.removeAll()
        previewCards.removeAll()
        previewExpectedCount = nil
        isLoadingDeck = true

        deckPreviewTask = Task { [weak self] in
            await KanjiDataLoader.loadCardsProgressively(deck: deck) { loadedCards, expectedCount in
                self?.applyKanjiPreviewUpdate(
                    loadedCards,
                    expectedCount: expectedCount,
                    deck: deck,
                    reviewStore: reviewStore
                )
            }

            self?.finishKanjiPreviewLoad(for: deck)
        }
    }

    func closeKanjiPreview() {
        cancelPreviewTask()
        previewDeck = nil
        previewCards.removeAll()
        previewExpectedCount = nil
        isLoadingDeck = false
    }

    func replaceKanjiPreviewCard(_ card: KanjiCard) {
        for index in previewCards.indices where previewCards[index].kanji == card.kanji {
            previewCards[index] = previewCards[index].mergedForDisplay(with: card)
        }
    }

    private func applyKanjiPreviewUpdate(
        _ loadedCards: [KanjiCard],
        expectedCount: Int?,
        deck: KanjiDeck,
        reviewStore: KanjiReviewStore
    ) {
        guard previewDeck == deck else {
            return
        }

        previewCards = reviewStore.orderedCards(uniqueCards(loadedCards))
        previewExpectedCount = expectedCount
        isLoadingDeck = previewExpectedCount.map { previewCards.count < $0 } ?? false
    }

    private func uniqueCards(_ cards: [KanjiCard]) -> [KanjiCard] {
        var cardsByKanji: [String: KanjiCard] = [:]
        for card in cards {
            if let existingCard = cardsByKanji[card.kanji] {
                cardsByKanji[card.kanji] = existingCard.mergedForDisplay(with: card)
            } else {
                cardsByKanji[card.kanji] = card
            }
        }

        return cardsByKanji.values.sorted { $0.kanji < $1.kanji }
    }

    private func finishKanjiPreviewLoad(for deck: KanjiDeck) {
        guard previewDeck == deck else {
            return
        }

        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
