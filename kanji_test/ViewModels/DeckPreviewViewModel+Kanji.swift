import Foundation

extension DeckPreviewViewModel {
    func openKanjiPreview(_ deck: KanjiDeck, reviewStore: StudyProgressStore) {
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
                    requestID: requestID,
                    reviewStore: reviewStore
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
        requestID: UUID,
        reviewStore: StudyProgressStore
    ) {
        guard previewDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
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

    private func finishKanjiPreviewLoad(for deck: KanjiDeck, requestID: UUID) {
        guard previewDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
            return
        }

        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
