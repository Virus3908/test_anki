import Foundation

extension TrainingSessionEngine {
    static func nextSessionItems<Item: StudyItem>(
        from sourceItems: [Item],
        reviewStore: KanjiReviewStore,
        newCardLimit: Int,
        learningSuccessTarget: Int
    ) -> (items: [Item], phase: KanjiLearningSessionPhase) {
        nextSessionItems(
            from: sourceItems,
            reviewStore: reviewStore,
            key: \.reviewKey,
            newCardLimit: newCardLimit,
            learningSuccessTarget: learningSuccessTarget
        )
    }

    static func nextSessionItems<Item>(
        from sourceItems: [Item],
        reviewStore: KanjiReviewStore,
        key: (Item) -> String,
        newCardLimit: Int,
        learningSuccessTarget: Int
    ) -> (items: [Item], phase: KanjiLearningSessionPhase) {
        let dueReviewItems = reviewStore.dueReviewItems(
            from: sourceItems,
            key: key,
            learningSuccessTarget: learningSuccessTarget
        )
        if !dueReviewItems.isEmpty {
            return (dueReviewItems, .review)
        }

        let learningItems = reviewStore.newLearningItems(
            from: sourceItems,
            key: key,
            newCardLimit: newCardLimit
        )
        if !learningItems.isEmpty {
            return (learningItems, .learning)
        }

        return (Array(sourceItems.shuffled().prefix(max(1, newCardLimit))), .fallbackReview)
    }
}
