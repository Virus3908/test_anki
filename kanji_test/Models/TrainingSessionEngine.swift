import Foundation

enum KanjiLearningSessionPhase {
    case review
    case learning
    case fallbackReview
}

struct SessionAnswerState {
    let reviewKey: String
    var rating: ReviewRating
    let recordBefore: KanjiReviewRecord?
    let againCountBefore: Int?
    let recoveryGoodCountBefore: Int?
    let wasMastered: Bool
}

struct ReviewAnswerPlan {
    let updatedRecoveryGoodCount: Int?
    let needsMoreRecovery: Bool
    let shouldUpdateSchedule: Bool
    let shouldResetIntervalOnGood: Bool
}

enum ReviewRepeatPlacement {
    case none
    case after(Int)
    case atEnd
}

struct ReviewQueueDecision {
    let isMastered: Bool
    let repeatPlacement: ReviewRepeatPlacement
    let additionalRepeatOffset: Int?
    let shouldClearRecoveryCounters: Bool
    let shouldRemoveFutureRepeats: Bool
}

enum TrainingSessionEngine {
    static func makeAnswerState(
        reviewKey: String,
        rating: ReviewRating,
        recordBefore: KanjiReviewRecord?,
        againCountBefore: Int?,
        recoveryGoodCountBefore: Int?,
        wasMastered: Bool
    ) -> SessionAnswerState {
        SessionAnswerState(
            reviewKey: reviewKey,
            rating: rating,
            recordBefore: recordBefore,
            againCountBefore: againCountBefore,
            recoveryGoodCountBefore: recoveryGoodCountBefore,
            wasMastered: wasMastered
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

    static func makeAnswerPlan(
        rating: ReviewRating,
        record: KanjiReviewRecord?,
        phase: KanjiLearningSessionPhase,
        mistakeCount: Int,
        recoveryGoodCount: Int
    ) -> ReviewAnswerPlan {
        let recovery = recoveryProgress(
            rating: rating,
            mistakeCount: mistakeCount,
            recoveryGoodCount: recoveryGoodCount
        )
        let needsMoreRecovery = recovery.needsMoreRecovery
        let shouldUpdateSchedule = phase != .fallbackReview && !needsMoreRecovery
        let shouldResetIntervalOnGood = rating == .good && record?.state == .review && mistakeCount >= 2

        return ReviewAnswerPlan(
            updatedRecoveryGoodCount: recovery.updatedGoodCount,
            needsMoreRecovery: needsMoreRecovery,
            shouldUpdateSchedule: shouldUpdateSchedule,
            shouldResetIntervalOnGood: shouldResetIntervalOnGood
        )
    }

    static func shouldScheduleAdditionalRepeat(mistakeCount: Int) -> Bool {
        mistakeCount >= 3
    }

    static func makeQueueDecision(
        rating: ReviewRating,
        isLearned: Bool,
        needsMoreRecovery: Bool,
        mistakeCount: Int
    ) -> ReviewQueueDecision {
        switch rating {
        case .again:
            return ReviewQueueDecision(
                isMastered: false,
                repeatPlacement: .after(2),
                additionalRepeatOffset: shouldScheduleAdditionalRepeat(mistakeCount: mistakeCount) ? 5 : nil,
                shouldClearRecoveryCounters: false,
                shouldRemoveFutureRepeats: false
            )
        case .hard:
            return ReviewQueueDecision(
                isMastered: false,
                repeatPlacement: .after(5),
                additionalRepeatOffset: nil,
                shouldClearRecoveryCounters: false,
                shouldRemoveFutureRepeats: false
            )
        case .good:
            if isLearned && !needsMoreRecovery {
                return ReviewQueueDecision(
                    isMastered: true,
                    repeatPlacement: .none,
                    additionalRepeatOffset: nil,
                    shouldClearRecoveryCounters: true,
                    shouldRemoveFutureRepeats: true
                )
            }

            return ReviewQueueDecision(
                isMastered: false,
                repeatPlacement: .atEnd,
                additionalRepeatOffset: nil,
                shouldClearRecoveryCounters: false,
                shouldRemoveFutureRepeats: false
            )
        }
    }

    static func applyQueueDecision<Item>(
        _ decision: ReviewQueueDecision,
        item: Item,
        key: String,
        currentIndex: Int,
        items: inout [Item],
        keyFor: (Item) -> String
    ) {
        switch decision.repeatPlacement {
        case .none:
            if decision.shouldRemoveFutureRepeats {
                removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            }
        case .after(let offset):
            removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            insertRepeat(item, after: offset, currentIndex: currentIndex, items: &items)

            if let additionalRepeatOffset = decision.additionalRepeatOffset {
                insertRepeat(item, after: additionalRepeatOffset, currentIndex: currentIndex, items: &items)
            }
        case .atEnd:
            removeFutureRepeats(after: currentIndex, key: key, items: &items, keyFor: keyFor)
            items.append(item)
        }
    }

    static func removeFutureRepeats<Item>(
        after index: Int,
        key: String,
        items: inout [Item],
        keyFor: (Item) -> String
    ) {
        guard index + 1 < items.count else {
            return
        }

        for itemIndex in items.indices.reversed() where itemIndex > index && keyFor(items[itemIndex]) == key {
            items.remove(at: itemIndex)
        }
    }

    private static func insertRepeat<Item>(
        _ item: Item,
        after offset: Int,
        currentIndex: Int,
        items: inout [Item]
    ) {
        let insertIndex = min(currentIndex + offset, items.count)
        items.insert(item, at: insertIndex)
    }

    private static func recoveryProgress(
        rating: ReviewRating,
        mistakeCount: Int,
        recoveryGoodCount: Int
    ) -> (updatedGoodCount: Int?, needsMoreRecovery: Bool) {
        guard rating == .good, mistakeCount >= 2 else {
            return (nil, false)
        }

        let updatedGoodCount = recoveryGoodCount + 1
        let requiredGoodCount = 1 + (mistakeCount / 2)
        return (updatedGoodCount, updatedGoodCount < requiredGoodCount)
    }
}
