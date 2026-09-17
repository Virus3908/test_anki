import Foundation

extension TrainingReviewService {
    static func applyQueueDecision<Item: StudyItem>(
        _ decision: ReviewQueueDecision,
        item: Item,
        key: String,
        session: inout TrainingSessionState,
        items: inout [Item]
    ) {
        if decision.isMastered {
            session.masteredKeys.insert(key)
        } else {
            session.masteredKeys.remove(key)
        }

        TrainingSessionEngine.applyQueueDecision(
            decision,
            item: item,
            key: key,
            currentIndex: session.currentIndex,
            items: &items
        )

        if decision.shouldClearRecoveryCounters {
            session.kanjiAgainCounts[key] = nil
            session.kanjiRecoveryGoodCounts[key] = nil
        }
    }
}
