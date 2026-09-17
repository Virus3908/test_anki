import Foundation

extension DeckPreviewViewModel {
    func openWordPreview(_ deck: WordFrequencyDeck) {
        guard !isLoadingDeck else {
            return
        }

        cancelPreviewTask()
        navigation.route = .wordDeck(deck)
        loadError = nil
        previewWordCards.removeAll()
        isLoadingDeck = true

        let requestID = previewRequestID
        let provider = kanjiProvider
        deckPreviewTask = Task { [weak self] in
            do {
                let preparedWords = try await WordDataLoader.loadWords(for: deck, provider: provider)
                self?.finishWordPreviewLoad(preparedWords, for: deck, requestID: requestID)
            } catch {
                guard let self, self.previewRequestID == requestID, !Task.isCancelled else { return }
                self.loadError = "Не удалось загрузить словарь: \(error.localizedDescription)"
                self.isLoadingDeck = false
                self.deckPreviewTask = nil
            }
        }
    }

    func closeWordPreview() {
        cancelPreviewTask()
        navigation.route = .start
        previewWordCards.removeAll()
        isLoadingDeck = false
    }

    private func finishWordPreviewLoad(_ loadedCards: [WordStudyCard], for deck: WordFrequencyDeck, requestID: UUID) {
        guard previewWordDeck == deck, previewRequestID == requestID, !Task.isCancelled else {
            return
        }

        previewWordCards = loadedCards
        isLoadingDeck = false
        deckPreviewTask = nil
    }
}
