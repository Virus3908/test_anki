import Foundation
import Testing
@testable import kanji_test

private struct TestStudyItem: StudyItem, Equatable {
    let id: String

    var reviewKey: String { id }
    var displayTitle: String { id }
    var displaySubtitle: String { "" }
    var strokes: [KanjiStroke] { [] }
}

@Suite("Training session engine")
struct TrainingSessionEngineTests {
    @Test
    func dueReviewItemsAreNotLimitedByNewCardLimit() {
        let now = Date()
        let items = ["a", "b", "c"].map(TestStudyItem.init(id:))
        let records = Dictionary(uniqueKeysWithValues: items.map { item in
            (
                item.reviewKey,
                KanjiReviewRecord(
                    attempts: 3,
                    successes: 2,
                    streak: 2,
                    intervalDays: 1,
                    dueDate: now.addingTimeInterval(-60),
                    lastRating: .good,
                    lastReviewedAt: now.addingTimeInterval(-86_400),
                    state: .review,
                    learningStep: 2
                )
            )
        })

        let result = TrainingSessionEngine.nextSessionItems(
            from: items,
            reviewStore: KanjiReviewStore(records: records),
            newCardLimit: 1,
            learningSuccessTarget: 2
        )

        #expect(result.phase == .review)
        #expect(result.items.map(\.reviewKey) == ["a", "b", "c"])
    }

    @Test
    func newLearningItemsRespectNewCardLimit() {
        let items = ["a", "b", "c"].map(TestStudyItem.init(id:))

        let result = TrainingSessionEngine.nextSessionItems(
            from: items,
            reviewStore: KanjiReviewStore(records: [:]),
            newCardLimit: 2,
            learningSuccessTarget: 2
        )

        #expect(result.phase == .learning)
        #expect(result.items.map(\.reviewKey) == ["a", "b"])
    }

    @Test
    func repeatedMistakesRequireExtraRecoverySuccesses() {
        let firstGood = TrainingSessionEngine.makeAnswerPlan(
            rating: .good,
            record: nil,
            phase: .learning,
            mistakeCount: 2,
            recoveryGoodCount: 0
        )

        let secondGood = TrainingSessionEngine.makeAnswerPlan(
            rating: .good,
            record: nil,
            phase: .learning,
            mistakeCount: 2,
            recoveryGoodCount: firstGood.updatedRecoveryGoodCount ?? 0
        )

        #expect(firstGood.needsMoreRecovery)
        #expect(firstGood.shouldUpdateSchedule == false)
        #expect(firstGood.updatedRecoveryGoodCount == 1)
        #expect(secondGood.needsMoreRecovery == false)
        #expect(secondGood.shouldUpdateSchedule)
    }

    @Test
    func againSchedulesRepeatAndAdditionalRepeatAfterThreeMistakes() {
        let item = TestStudyItem(id: "a")
        var items = [
            item,
            TestStudyItem(id: "b"),
            TestStudyItem(id: "c")
        ]
        let decision = TrainingSessionEngine.makeQueueDecision(
            rating: .again,
            isLearned: false,
            needsMoreRecovery: false,
            mistakeCount: 3
        )

        TrainingSessionEngine.applyQueueDecision(
            decision,
            item: item,
            key: item.reviewKey,
            currentIndex: 0,
            items: &items
        )

        #expect(items.map(\.reviewKey) == ["a", "a", "b", "c", "a"])
    }

    @Test
    func successfulReviewClearsFutureRepeats() {
        let item = TestStudyItem(id: "a")
        var items = [
            item,
            TestStudyItem(id: "b"),
            item,
            TestStudyItem(id: "c")
        ]
        let decision = TrainingSessionEngine.makeQueueDecision(
            rating: .good,
            isLearned: true,
            needsMoreRecovery: false,
            mistakeCount: 0
        )

        TrainingSessionEngine.applyQueueDecision(
            decision,
            item: item,
            key: item.reviewKey,
            currentIndex: 0,
            items: &items
        )

        #expect(decision.isMastered)
        #expect(items.map(\.reviewKey) == ["a", "b", "c"])
    }
}
