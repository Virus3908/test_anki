import Foundation

extension TrainingSessionViewModel {
    func nextSessionItems<Item: StudyItem>(
        from sourceItems: [Item],
        reviewStore: KanjiReviewStore,
        newCardLimit: Int,
        learningSuccessTarget: Int
    ) -> [Item] {
        let result = TrainingSessionEngine.nextSessionItems(
            from: sourceItems,
            reviewStore: reviewStore,
            newCardLimit: newCardLimit,
            learningSuccessTarget: learningSuccessTarget
        )
        kanjiSessionPhase = result.phase
        return result.items
    }

    func startNextPack<Item: StudyItem>(
        from sourceCards: [Item],
        reviewStore: KanjiReviewStore,
        newCardLimit: Int,
        learningSuccessTarget: Int,
        applyCards: ([Item]) -> Void
    ) -> Bool {
        guard !sourceCards.isEmpty, !isGuidedSingleKanjiPractice else {
            return false
        }

        let nextCards = nextSessionItems(
            from: sourceCards,
            reviewStore: reviewStore,
            newCardLimit: newCardLimit,
            learningSuccessTarget: learningSuccessTarget
        )
        guard !nextCards.isEmpty else {
            return false
        }

        applyCards(nextCards)
        prepareStudyPack(nextCards, scrollToTop: true)
        return true
    }
}
