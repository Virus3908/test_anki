import Foundation

extension DeckPreviewViewModel {
    func openKanaPreview(_ deck: KanaDeck) {
        cancelPreviewTask()
        previewKanaDeck = deck
        previewDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards = deck.baseCards
        isLoadingDeck = true

        deckPreviewTask = Task { [weak self] in
            let loadedCards = await KanaDataLoader.loadCards(deck: deck)
            self?.finishKanaPreviewLoad(loadedCards, for: deck)
        }
    }

    func closeKanaPreview() {
        cancelPreviewTask()
        previewKanaDeck = nil
        previewKanaCards.removeAll()
        isLoadingDeck = false
    }

    private func finishKanaPreviewLoad(_ loadedCards: [KanaStudyCard], for deck: KanaDeck) {
        guard previewKanaDeck == deck else {
            return
        }

        previewKanaCards = loadedCards
        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
