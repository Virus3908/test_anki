import Foundation

extension StudyAppViewModel {
    func startRandomTrainingFromPreview() { startTraining(with: deckState.previewCards, guided: false) }
    func startTraining(with cards: [KanjiCard], sourceCards: [KanjiCard]? = nil, guided: Bool) {
        start(mode: .kanji, ids: catalog.register(guided ? cards : sourceCards ?? cards), guided: guided)
    }
    func startWordTraining(with cards: [WordStudyCard], sourceCards: [WordStudyCard]? = nil, guided: Bool = false) {
        start(mode: .words, ids: catalog.register(guided ? cards : sourceCards ?? cards), guided: guided)
    }
    func startKanaTraining(deck: KanaDeck, cards: [KanaStudyCard]? = nil, sourceCards: [KanaStudyCard]? = nil, guided: Bool = false) {
        coordinator.selectedKanaDeck = deck
        start(mode: .kana, ids: catalog.register(guided ? cards ?? deck.cards : sourceCards ?? cards ?? deck.cards), guided: guided)
    }
    private func start(mode: PracticeMode, ids: [String], guided: Bool) {
        guard hasLoadedSavedState else { return }
        Task {
            if await trainingSession.start(mode: mode, sourceIDs: ids, guided: guided) {
                selectedPracticeMode = mode
                deckState.cancelPreviewTask()
                deckState.isLoadingDeck = false
                coordinator.resetPreviewSelection()
                navigation.beginTraining(mode)
            }
        }
    }
}
