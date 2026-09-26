import XCTest
@testable import kanji_test

final class CardMasteryTests: XCTestCase {
    private let calendar = Calendar.current
    /// Фиксированное «сегодня», чтобы календарные сутки в тестах не плыли.
    private let now = Date(timeIntervalSince1970: 1_767_225_600)

    private func makeRecord(state: StudyReviewState = .review,
                            attempts: Int = 5,
                            stability: Double = 10,
                            difficulty: Double = 5,
                            reviewedDaysAgo days: Int) -> StudyReviewRecord {
        let startOfToday = calendar.startOfDay(for: now)
        let lastReviewedAt = calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? now
        return StudyReviewRecord(attempts: attempts, intervalDays: 10, dueDate: now,
                                 lastRating: .good, lastReviewedAt: lastReviewedAt, state: state,
                                 learningStep: 0, lapses: 0, stability: stability,
                                 difficulty: difficulty, schedulerVersion: "fsrs-6")
    }

    private func score(_ record: StudyReviewRecord?) -> Double? {
        guard case .score(let value) = CardMastery(record: record, isExcluded: false, now: now) else {
            return nil
        }
        return value
    }

    func testNoRecordOrUnansweredIsUntrained() {
        XCTAssertEqual(CardMastery(record: nil, isExcluded: false, now: now), .untrained)
        XCTAssertEqual(CardMastery(record: makeRecord(attempts: 0, reviewedDaysAgo: 0),
                                    isExcluded: false, now: now), .untrained)
    }

    func testExcludedBeatsRecord() {
        let record = makeRecord(reviewedDaysAgo: 0)
        XCTAssertEqual(CardMastery(record: record, isExcluded: true, now: now), .excluded)
    }

    func testLearningSitsInNeutralBand() {
        let value = score(makeRecord(state: .learning, reviewedDaysAgo: 0))
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 0.45, accuracy: 0.001)
    }

    func testRelearningSitsDeepInProblemBand() {
        let value = score(makeRecord(state: .relearning, reviewedDaysAgo: 0))
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 0.2, accuracy: 0.001)
    }

    func testFreshEasyReviewScoresHigh() {
        let fresh = score(makeRecord(stability: 30, difficulty: 1, reviewedDaysAgo: 0))
        XCTAssertNotNil(fresh)
        XCTAssertGreaterThan(fresh!, 0.7)
    }

    func testOverdueReviewScoresLow() {
        let overdue = score(makeRecord(stability: 10, difficulty: 9, reviewedDaysAgo: 90))
        XCTAssertNotNil(overdue)
        XCTAssertLessThan(overdue!, 0.4)
    }

    func testHarderDifficultyMeansLowerScore() {
        let easy = score(makeRecord(stability: 30, difficulty: 1, reviewedDaysAgo: 3))!
        let hard = score(makeRecord(stability: 30, difficulty: 9, reviewedDaysAgo: 3))!
        XCTAssertGreaterThan(easy, hard)
    }

    func testLongerIdleLowersScore() {
        let fresh = score(makeRecord(stability: 10, difficulty: 5, reviewedDaysAgo: 0))!
        let idle = score(makeRecord(stability: 10, difficulty: 5, reviewedDaysAgo: 30))!
        XCTAssertGreaterThan(fresh, idle)
    }
}
