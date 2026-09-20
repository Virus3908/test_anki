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
        XCTAssertEqual(plan.hiddenReviews, 2)
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
