import Foundation

extension StudyAppViewModel {
    var customTrainingDeck: StudyDeck? { navigation.deckRoute.deck }

    /// Puts the open deck preview into card selection mode.
    func beginCustomSelection() {
        guard customTrainingDeck != nil else { return }
        customTraining.setSelection(customTraining.selectedIDs.intersection(Set(selectableCardIDs())))
        customTraining.beginSelection()
    }

    /// Starts the endless session with the cards picked in the deck preview.
    func startCustomTraining() {
        guard let deck = customTrainingDeck else { return }
        let selection = customTraining.selectedIDs
        let cardIDs: [String]
        switch deck.mode {
        case .kanji:
            cardIDs = deckState.previewCards.filter { selection.contains($0.id) }.map(\.id)
        case .words:
            cardIDs = deckState.previewWordCards.filter { selection.contains($0.id) }.map(\.id)
        case .kana:
            cardIDs = deckState.previewKanaCards.filter { selection.contains($0.id) }.map(\.id)
        case .anki:
            // Anki preview cards are not catalog-registered like built-in decks;
            // register the chosen subset so the session can resolve them.
            cardIDs = catalog.register(ankiLibrary.previewCards.filter { selection.contains($0.id) })
        }
        guard !cardIDs.isEmpty else { return }
        customTraining.finishSelection()
        customTraining.start(deck: deck, cardIDs: cardIDs)
        navigation.beginCustomTraining()
    }

    func finishCustomTraining() {
        customTraining.stop()
        navigation.finishCustomTraining()
    }

    /// Cards of the currently open deck available for custom selection.
    private func selectableCardIDs() -> [String] {
        switch customTrainingDeck?.mode {
        case .kanji: return deckState.previewCards.map(\.id)
        case .words: return deckState.previewWordCards.map(\.id)
        case .kana: return deckState.previewKanaCards.map(\.id)
        case .anki: return ankiLibrary.previewCards.map(\.id)
        case nil: return []
        }
    }
}
