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
    func fallbackReviewUsesDeckWhenEverythingIsLearnedAndNothingIsDue() {
        let now = Date()
        let items = ["a", "b", "c"].map(TestStudyItem.init(id:))
        let records = Dictionary(uniqueKeysWithValues: items.map { item in
            (
                item.reviewKey,
                KanjiReviewRecord(
                    attempts: 4,
                    successes: 4,
                    streak: 4,
                    intervalDays: 7,
                    dueDate: now.addingTimeInterval(86_400 * 7),
                    lastRating: .good,
                    lastReviewedAt: now,
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

        #expect(result.phase == .fallbackReview)
        #expect(result.items.count == 1)
        #expect(items.map(\.reviewKey).contains(result.items[0].reviewKey))
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

@Suite("Kanji review scheduler")
struct KanjiReviewSchedulerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func newCardNeedsConfiguredGoodCountBeforeReview() {
        let firstGood = KanjiReviewScheduler.record(
            after: .good,
            existingRecord: nil,
            learningSuccessTarget: 2,
            resetIntervalOnGood: false,
            now: now
        )

        let secondGood = KanjiReviewScheduler.record(
            after: .good,
            existingRecord: firstGood,
            learningSuccessTarget: 2,
            resetIntervalOnGood: false,
            now: now
        )

        #expect(firstGood.state == .learning)
        #expect(firstGood.learningStep == 1)
        #expect(firstGood.intervalDays == 0)
        #expect(sameDay(firstGood.dueDate, now))

        #expect(secondGood.state == .review)
        #expect(secondGood.learningStep == 2)
        #expect(secondGood.intervalDays == 1)
        #expect(daysBetween(now, secondGood.dueDate) == 1)
    }

    @Test
    func successfulReviewMultipliesIntervalByEaseFactor() {
        let existing = KanjiReviewRecord(
            attempts: 3,
            successes: 2,
            streak: 2,
            intervalDays: 2,
            dueDate: now,
            lastRating: .good,
            lastReviewedAt: now.addingTimeInterval(-86_400),
            state: .review,
            learningStep: 2,
            easeFactor: 2.5
        )

        let result = KanjiReviewScheduler.record(
            after: .good,
            existingRecord: existing,
            learningSuccessTarget: 2,
            resetIntervalOnGood: false,
            now: now
        )

        #expect(result.state == .review)
        #expect(result.intervalDays == 5)
        #expect(daysBetween(now, result.dueDate) == 5)
        #expect(result.streak == 3)
    }

    @Test
    func goodAfterMultipleMistakesRestartsReviewIntervalFromOneDay() {
        let existing = KanjiReviewRecord(
            attempts: 6,
            successes: 4,
            streak: 0,
            intervalDays: 12,
            dueDate: now,
            lastRating: .again,
            lastReviewedAt: now,
            state: .review,
            learningStep: 2,
            easeFactor: 2.5,
            lapses: 1
        )

        let result = KanjiReviewScheduler.record(
            after: .good,
            existingRecord: existing,
            learningSuccessTarget: 2,
            resetIntervalOnGood: true,
            now: now
        )

        #expect(result.state == .review)
        #expect(result.intervalDays == 1)
        #expect(daysBetween(now, result.dueDate) == 1)
    }

    @Test
    func againOnReviewCardMovesToRelearningAndKeepsDueToday() {
        let existing = KanjiReviewRecord(
            attempts: 4,
            successes: 3,
            streak: 3,
            intervalDays: 10,
            dueDate: now,
            lastRating: .good,
            lastReviewedAt: now.addingTimeInterval(-86_400),
            state: .review,
            learningStep: 2,
            easeFactor: 2.5
        )

        let result = KanjiReviewScheduler.record(
            after: .again,
            existingRecord: existing,
            learningSuccessTarget: 2,
            resetIntervalOnGood: false,
            now: now
        )

        #expect(result.state == .relearning)
        #expect(result.learningStep == 0)
        #expect(result.lapses == 1)
        #expect(result.streak == 0)
        #expect(result.intervalDays == 1)
        #expect(sameDay(result.dueDate, now))
        #expect(result.easeFactor == 2.3)
    }

    private func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int? {
        Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}
