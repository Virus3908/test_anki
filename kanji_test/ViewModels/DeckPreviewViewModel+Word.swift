import Foundation

extension DeckPreviewViewModel {
    func openWordPreview(_ deck: WordFrequencyDeck) {
        guard !isLoadingDeck else {
            return
        }

        cancelPreviewTask()
        previewWordDeck = deck
        previewDeck = nil
        previewKanaDeck = nil
        previewWordCards.removeAll()
        isLoadingDeck = true

        deckPreviewTask = Task { [weak self] in
            let allWords = await WordDataLoader.loadWords()
            let preparedWords = deck.cards(from: allWords)
            self?.finishWordPreviewLoad(preparedWords, for: deck)
        }
    }

    func closeWordPreview() {
        cancelPreviewTask()
        previewWordDeck = nil
        previewWordCards.removeAll()
        isLoadingDeck = false
    }

    func replacePreviewWordCards(using transform: (WordStudyCard) -> WordStudyCard) {
        for index in previewWordCards.indices {
            previewWordCards[index] = transform(previewWordCards[index])
        }
    }

    private func finishWordPreviewLoad(_ loadedCards: [WordStudyCard], for deck: WordFrequencyDeck) {
        guard previewWordDeck == deck else {
            return
        }

        previewWordCards = loadedCards
        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
