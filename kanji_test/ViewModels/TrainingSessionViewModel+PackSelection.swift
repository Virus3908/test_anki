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

    func applyCurrentItemReview<Item: StudyItem>(
        rating: ReviewRating,
        mode: PracticeMode,
        expectedKey: String? = nil,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        learningSuccessTarget: Int
    ) -> Bool {
        guard items.indices.contains(currentIndex), !isPreparingCard else {
            return false
        }

        let item = items[currentIndex]
        if let expectedKey, item.reviewKey != expectedKey {
            return false
        }

        return applyStudyItemReview(
            item,
            rating: rating,
            mode: mode,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items,
            learningSuccessTarget: learningSuccessTarget
        )
    }

    func applyStudyItemReview<Item: StudyItem>(
        _ item: Item,
        rating: ReviewRating,
        mode: PracticeMode,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        learningSuccessTarget: Int
    ) -> Bool {
        TrainingReviewService.applyReview(
            item: item,
            rating: rating,
            mode: mode,
            session: self,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items,
            learningSuccessTarget: learningSuccessTarget
        )
    }

    func evaluateFeedback(for card: KanjiCard, reveal: Bool) -> Bool {
        drawingSession.evaluateFeedback(for: card, reveal: reveal)
    }
}
