import Foundation

extension StudyCoordinator {
    func beginKanjiTraining(
        with trainingCards: [KanjiCard],
        sourceCards: [KanjiCard],
        deckState: DeckPreviewViewModel,
        trainingSession: TrainingSessionViewModel,
        guided: Bool
    ) {
        guard !trainingCards.isEmpty else {
            return
        }

        deckState.prepareKanjiTrainingSource(sourceCards)
        useKanjiTrainingCards(trainingCards)
        beginTrainingSession(with: trainingCards, trainingSession: trainingSession, guided: guided)
    }

    func beginWordTraining(
        with trainingCards: [WordStudyCard],
        sourceCards: [WordStudyCard],
        deckState: DeckPreviewViewModel,
        trainingSession: TrainingSessionViewModel,
        guided: Bool
    ) {
        guard !trainingCards.isEmpty else {
            return
        }

        useWordTrainingCards(trainingCards)
        deckState.prepareWordTrainingSource(sourceCards)
        beginTrainingSession(with: trainingCards, trainingSession: trainingSession, guided: guided)
    }

    func beginKanaTraining(
        deck: KanaDeck,
        trainingCards: [KanaStudyCard],
        sourceCards: [KanaStudyCard],
        deckState: DeckPreviewViewModel,
        trainingSession: TrainingSessionViewModel,
        guided: Bool
    ) {
        guard !trainingCards.isEmpty else {
            return
        }

        selectedKanaDeck = deck
        deckState.prepareKanaTrainingSource(sourceCards)
        useKanaTrainingCards(trainingCards)
        beginTrainingSession(with: trainingCards, trainingSession: trainingSession, guided: guided)
    }

    func finishTraining(deckState: DeckPreviewViewModel, trainingSession: TrainingSessionViewModel) {
        clearTrainingCards()
        deckState.clearTrainingSources()
        trainingSession.resetFinishedSession()
        hasStartedTraining = false
        resetPreviewSelection()
    }

    func resetAfterDeckCacheClear(deckState: DeckPreviewViewModel, trainingSession: TrainingSessionViewModel) {
        clearTrainingCards()
        deckState.clearCacheState()
        resetPreviewSelection()
        trainingSession.resetFinishedSession()
    }

    func beginTrainingSession<Item: StudyItem>(
        with trainingItems: [Item],
        trainingSession: TrainingSessionViewModel,
        guided: Bool
    ) {
        trainingSession.prepareStudyPack(trainingItems, guided: guided)
        hasStartedTraining = !trainingItems.isEmpty
    }
}
