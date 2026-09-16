import SwiftUI

extension ContentView {
    func advanceToNextKanjiOrFinish() async {
        guard trainingSession.sessionCompletedCards < trainingSession.sessionTotalCards else {
            if !trainingSession.isGuidedSingleKanjiPractice, startNextKanjiPack() {
                return
            }

            finishTraining()
            return
        }

        guard trainingSession.currentIndex < cards.count - 1 else {
            return
        }

        await prepareAndMoveToCard(at: trainingSession.currentIndex + 1)
    }

    func advanceToNextOrFinish(
        hasNextCard: Bool,
        startNextPack: () -> Bool,
        moveToNextCard: () -> Void
    ) {
        guard trainingSession.sessionCompletedCards < trainingSession.sessionTotalCards else {
            if startNextPack() {
                return
            }

            finishTraining()
            return
        }

        guard hasNextCard else {
            return
        }

        moveToNextCard()
    }

    func startNextWordPack() -> Bool {
        startNextPack(from: deckState.wordTrainingSourceCards) { nextCards in
            coordinator.useWordTrainingCards(nextCards)
        }
    }

    func startNextKanaPack() -> Bool {
        startNextPack(from: deckState.kanaTrainingSourceCards) { nextCards in
            coordinator.useKanaTrainingCards(nextCards)
        }
    }

    func startNextKanjiPack() -> Bool {
        startNextPack(from: deckState.kanjiTrainingSourceCards) { nextCards in
            coordinator.useKanjiTrainingCards(nextCards)
        }
    }

    func startNextPack<Item: StudyItem>(
        from sourceCards: [Item],
        onStart apply: ([Item]) -> Void
    ) -> Bool {
        trainingSession.startNextPack(
            from: sourceCards,
            reviewStore: reviewStore,
            newCardLimit: kanjiDailyNewCardLimit,
            learningSuccessTarget: kanjiLearningSuccessTarget,
            applyCards: apply
        )
    }

    func finishTraining() {
        coordinator.finishTraining(deckState: deckState, trainingSession: trainingSession)
    }

    func moveToPreviousCard() {
        guard trainingSession.currentIndex > 0, !trainingSession.isPreparingCard else {
            return
        }

        trainingSession.moveToPreviousCard()
    }

    func moveToNextCard() {
        guard !trainingSession.isPreparingCard else {
            return
        }

        switch practiceMode {
        case .kanji:
            guard trainingSession.currentIndex < cards.count - 1 else {
                return
            }
            let targetIndex = trainingSession.currentIndex + 1
            Task { @MainActor in
                await prepareAndMoveToCard(at: targetIndex)
            }
        case .words:
            guard trainingSession.currentIndex < wordCards.count - 1 else {
                return
            }
            trainingSession.moveToNextCard(resetWordDrawing: true)
        case .kana:
            guard trainingSession.currentIndex < kanaCards.count - 1 else {
                return
            }
            trainingSession.moveToNextCard()
        }
    }

    func prepareAndMoveToCard(at targetIndex: Int) async {
        guard cards.indices.contains(targetIndex), !trainingSession.isPreparingCard else {
            return
        }

        trainingSession.isPreparingCard = true

        let deck = selectedDeck

        guard selectedDeck == deck, cards.indices.contains(targetIndex) else {
            trainingSession.isPreparingCard = false
            return
        }

        trainingSession.moveToCard(at: targetIndex)
        trainingSession.isPreparingCard = false
    }
}
