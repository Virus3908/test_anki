import Foundation

extension DeckPreviewViewModel {
    func openKanaPreview(_ deck: KanaDeck) {
        cancelPreviewTask()
        navigation.open(.kanaDeck(deck))
        loadError = nil
        previewWordCards.removeAll()
        previewKanaCards.removeAll()
        isLoadingDeck = true

        let requestID = previewRequestID
        deckPreviewTask = Task { [weak self] in
            do {
                let loadedCards = try await KanaDataLoader.loadCards(deck: deck)
                self?.finishKanaPreviewLoad(loadedCards, for: deck, requestID: requestID)
            } catch {
                guard let self, previewKanaDeck == deck, previewRequestID == requestID, !Task.isCancelled else { return }
                loadError = "Не удалось загрузить данные каны: \(error.localizedDescription)"
                isLoadingDeck = false
                deckPreviewTask = nil
            }
        }
    }

    func closeKanaPreview() {
        cancelPreviewTask()
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
