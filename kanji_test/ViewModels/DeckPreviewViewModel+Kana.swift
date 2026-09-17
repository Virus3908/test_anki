import Foundation

extension DeckPreviewViewModel {
    func openKanaPreview(_ deck: KanaDeck) {
        cancelPreviewTask()
        navigation.route = .kanaDeck(deck)
        loadError = nil
        previewWordCards.removeAll()
        previewKanaCards = deck.baseCards
        isLoadingDeck = true

        let requestID = previewRequestID
        deckPreviewTask = Task { [weak self] in
            let loadedCards = await KanaDataLoader.loadCards(deck: deck)
            self?.finishKanaPreviewLoad(loadedCards, for: deck, requestID: requestID)
        }
    }

    func closeKanaPreview() {
        cancelPreviewTask()
        navigation.route = .start
        previewKanaCards.removeAll()
        isLoadingDeck = false
    }

    private func finishKanaPreviewLoad(_ loadedCards: [KanaStudyCard], for deck: KanaDeck, requestID: UUID) {
        guard previewKanaDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
            return
        }

        previewKanaCards = loadedCards
        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
