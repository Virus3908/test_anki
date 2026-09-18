import Foundation

extension StudyAppViewModel {
    func startRandomTrainingFromPreview() { startTraining(with: deckState.previewCards, guided: false) }
    func startTraining(with cards: [KanjiCard], sourceCards: [KanjiCard]? = nil, guided: Bool) {
        start(deck: .kanji(coordinator.selectedDeck), ids: catalog.register(guided ? cards : sourceCards ?? cards), guided: guided)
    }
    func startWordTraining(with cards: [WordStudyCard], sourceCards: [WordStudyCard]? = nil, guided: Bool = false) {
        start(deck: .words(coordinator.selectedWordDeck), ids: catalog.register(guided ? cards : sourceCards ?? cards), guided: guided)
    }
    func startKanaTraining(deck: KanaDeck, cards: [KanaStudyCard]? = nil, sourceCards: [KanaStudyCard]? = nil, guided: Bool = false) {
        coordinator.selectedKanaDeck = deck
        start(deck: .kana(deck), ids: catalog.register(guided ? cards ?? deck.cards : sourceCards ?? cards ?? deck.cards), guided: guided)
    }
    func startAnkiTraining(deck: AnkiDeckReference, cards: [AnkiStudyCard], guided: Bool = false) {
        start(deck: deck.studyDeck, ids: catalog.register(cards), guided: guided)
    }
    private func start(deck: StudyDeck, ids: [String], guided: Bool) {
        guard hasLoadedSavedState else { return }
        Task {
            if await trainingSession.start(deck: deck, sourceIDs: ids, guided: guided) {
                selectedPracticeMode = deck.mode
                deckState.cancelPreviewTask()
                deckState.isLoadingDeck = false
                coordinator.resetPreviewSelection()
                if trainingSession.didCompleteToday {
                    isTodayCompletionPresented = true
                } else {
                    navigation.beginTraining(deck.mode)
                }
            }
        }
    }
}
