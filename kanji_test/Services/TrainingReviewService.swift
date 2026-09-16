import Foundation

@MainActor
enum TrainingReviewService {
    static func applyReview<Item: StudyItem>(
        item: Item,
        rating: ReviewRating,
        mode: PracticeMode,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        learningSuccessTarget: Int
    ) -> Bool {
        if session.isGuidedSingleKanjiPractice {
            applyPracticeOnlyReview(item: item, rating: rating, mode: mode, session: session)
            return false
        }

        let key = item.reviewKey
        let answerID = session.currentAnswerID(for: mode)
        let existingAnswer = session.sessionAnswerStates[answerID]
        prepareReviewReapply(
            existingAnswer,
            key: key,
            mode: mode,
            session: session,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items
        )

        return applyReviewedItem(
            item,
            rating: rating,
            key: key,
            mode: mode,
            existingAnswer: existingAnswer,
            session: session,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items,
            learningSuccessTarget: learningSuccessTarget
        )
    }

    private static func applyReviewedItem<Item: StudyItem>(
        _ reviewedItem: Item,
        rating: ReviewRating,
        key: String,
        mode: PracticeMode,
        existingAnswer: SessionAnswerState?,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        learningSuccessTarget: Int
    ) -> Bool {
        var answerState = existingAnswer ?? TrainingSessionEngine.makeAnswerState(
            reviewKey: key,
            rating: rating,
            recordBefore: reviewStore.record(for: key),
            againCountBefore: session.kanjiAgainCounts[key],
            recoveryGoodCountBefore: session.kanjiRecoveryGoodCounts[key],
            wasMastered: masteredKeys.contains(key)
        )
        let answerPlan = makeAndApplyAnswerPlan(
            for: key,
            rating: rating,
            session: session,
            reviewStore: &reviewStore,
            learningSuccessTarget: learningSuccessTarget
        )
        let isLearned = reviewStore.record(for: key)?.state == .review

        if rating == .again {
            session.kanjiAgainCounts[key, default: 0] += 1
            session.kanjiRecoveryGoodCounts[key] = 0
        }

        let queueDecision = TrainingSessionEngine.makeQueueDecision(
            rating: rating,
            isLearned: isLearned,
            needsMoreRecovery: answerPlan.needsMoreRecovery,
            mistakeCount: session.kanjiAgainCounts[key, default: 0]
        )

        applyQueueDecision(
            queueDecision,
            item: reviewedItem,
            key: key,
            session: session,
            masteredKeys: &masteredKeys,
            items: &items
        )

        session.sessionCompletedCards = masteredKeys.count
        answerState.rating = rating
        session.sessionAnswerStates[session.currentAnswerID(for: mode)] = answerState
        return existingAnswer == nil
    }

    private static func makeAndApplyAnswerPlan(
        for key: String,
        rating: ReviewRating,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        learningSuccessTarget: Int
    ) -> ReviewAnswerPlan {
        let answerPlan = TrainingSessionEngine.makeAnswerPlan(
            rating: rating,
            record: reviewStore.record(for: key),
            phase: session.kanjiSessionPhase,
            mistakeCount: session.kanjiAgainCounts[key, default: 0],
            recoveryGoodCount: session.kanjiRecoveryGoodCounts[key, default: 0]
        )
        if let updatedRecoveryGoodCount = answerPlan.updatedRecoveryGoodCount {
            session.kanjiRecoveryGoodCounts[key] = updatedRecoveryGoodCount
        }

        if answerPlan.shouldUpdateSchedule {
            reviewStore.apply(
                rating,
                to: key,
                learningSuccessTarget: learningSuccessTarget,
                resetIntervalOnGood: answerPlan.shouldResetIntervalOnGood
            )
            ReviewRepository.save(reviewStore)
        }

        return answerPlan
    }

}
