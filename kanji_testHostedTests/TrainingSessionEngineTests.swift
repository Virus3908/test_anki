import XCTest
@testable import kanji_test

@MainActor
final class TrainingSessionEngineTests: XCTestCase {
    func testReviewsAndNewCardsShareDailyLimit() {
        let now = Date()
        let progress = StudyProgressStore(records: [
            "review-1": dueReview(now: now),
            "review-2": dueReview(now: now),
            "review-3": dueReview(now: now)
        ])
        var options = DeckOptions()
        options.dailyNewCardLimit = 10
        options.dailyReviewLimit = 4

        let plan = TrainingSessionEngine.plan(
            sourceIDs: ["new-1", "new-2", "review-3", "review-1", "review-2"],
            mode: .kanji,
            deckID: "deck",
            progress: progress,
            options: options,
            now: now
        )

        XCTAssertEqual(plan.reviewCount, 3)
        XCTAssertEqual(plan.newCount, 1)
        XCTAssertEqual(plan.readyIDs.count, 4)
        XCTAssertEqual(Set(plan.readyIDs), ["review-1", "review-2", "review-3", "new-1"])
    }

    func testReviewBacklogUsesWholeDailyLimitBeforeNewCards() {
        let now = Date()
        let reviewIDs = (1...5).map { "review-\($0)" }
        let progress = StudyProgressStore(records: Dictionary(
            uniqueKeysWithValues: reviewIDs.map { ($0, dueReview(now: now)) }
        ))
        var options = DeckOptions()
        options.dailyNewCardLimit = 10
        options.dailyReviewLimit = 3

        let plan = TrainingSessionEngine.plan(
            sourceIDs: reviewIDs + ["new-1", "new-2"],
            mode: .kanji,
            deckID: "deck",
            progress: progress,
            options: options,
            now: now
        )

        XCTAssertEqual(plan.reviewCount, 3)
        XCTAssertEqual(plan.newCount, 0)
        XCTAssertEqual(plan.readyIDs, Array(reviewIDs.prefix(3)))
        XCTAssertEqual(plan.todayIDs, Array(reviewIDs.prefix(3)))
        XCTAssertEqual(plan.hiddenReviews, 2)
    }

    func testWaitingLearningStaysTodayWithoutJumpingAhead() {
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        for state in [StudyReviewState.learning, .relearning] {
            let waiting = StudyReviewRecord(attempts: 1, intervalDays: 0,
                dueDate: now.addingTimeInterval(600), lastRating: .again,
                lastReviewedAt: now, state: state, learningStep: 1,
                lapses: 0, stability: 1, difficulty: 5,
                schedulerVersion: StudyScheduler.version)
            let progress = StudyProgressStore(records: ["waiting": waiting, "review": dueReview(now: now)])
            let plan = TrainingSessionEngine.plan(sourceIDs: ["waiting", "review"], mode: .kanji,
                deckID: "deck", progress: progress, options: DeckOptions(), now: now)
            XCTAssertEqual(plan.readyIDs, ["review"])
            XCTAssertEqual(Set(plan.todayIDs), ["waiting", "review"])
            XCTAssertEqual(plan.nextLearningDate, waiting.dueDate)
        }
    }

    func testDailyCountersSurviveUndoDayChangeAndDecode() throws {
        let now = Date()
        var progress = StudyProgressStore(records: ["review": dueReview(now: now)])
        let keys: Set<String> = ["review", "new"]
        progress.markShown("new", now: now)
        XCTAssertEqual(progress.remainingNewCards(limit: 2, keys: keys, now: now), 1)
        let previous = progress.record(for: "review")
        let logID = try progress.apply(.good, to: "review", deckID: "deck", options: DeckOptions(), now: now)
        XCTAssertEqual(progress.remainingDailyCards(limit: 2, deckID: "deck", keys: keys, now: now), 0)
        progress = try JSONDecoder().decode(StudyProgressStore.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(progress.remainingDailyCards(limit: 2, deckID: "deck", keys: keys, now: now), 0)
        progress.undo(logID: logID, record: previous, key: "review")
        XCTAssertEqual(progress.remainingDailyCards(limit: 2, deckID: "deck", keys: keys, now: now), 1)
        progress.advanceStudyDay()
        XCTAssertEqual(progress.remainingDailyCards(limit: 2, deckID: "deck", keys: keys, now: now), 2)
        progress.resetProgress(for: ["new"])
        XCTAssertNil(progress.firstShownAt["new"])
    }

    func testRemovingAnkiImportPreservesOtherProgress() throws {
        let now = Date()
        let first = "anki:first:card:1"
        let second = "anki:second:card:1"
        var progress = StudyProgressStore(records: [first: dueReview(now: now), second: dueReview(now: now),
            "built-in": dueReview(now: now)])
        progress.markShown("anki:first:card:2", now: now)
        progress.exclude(first)
        progress.exclude(second)
        _ = try progress.apply(.good, to: first, deckID: "anki:first:deck:1", options: DeckOptions(), now: now)
        _ = try progress.apply(.good, to: second, deckID: "anki:second:deck:1", options: DeckOptions(), now: now)
        progress.removeAnkiImportProgress(importID: "first")
        XCTAssertNil(progress.record(for: first))
        XCTAssertNil(progress.firstShownAt["anki:first:card:2"])
        XCTAssertFalse(progress.isExcluded(first))
        XCTAssertFalse(progress.reviewLog.contains { $0.cardID == first })
        XCTAssertNotNil(progress.record(for: second))
        XCTAssertNotNil(progress.record(for: "built-in"))
        XCTAssertTrue(progress.isExcluded(second))
        XCTAssertTrue(progress.reviewLog.contains { $0.cardID == second })
    }

    private func dueReview(now: Date) -> StudyReviewRecord {
        StudyReviewRecord(
            attempts: 1,
            intervalDays: 1,
            dueDate: now.addingTimeInterval(-86_400),
            lastRating: .good,
            lastReviewedAt: now.addingTimeInterval(-172_800),
            state: .review,
            learningStep: 0,
            lapses: 0,
            stability: 1,
            difficulty: 5,
            schedulerVersion: StudyScheduler.version
        )
    }
}
