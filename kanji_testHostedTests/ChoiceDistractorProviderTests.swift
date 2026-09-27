import XCTest
@testable import kanji_test

final class ChoiceDistractorProviderTests: XCTestCase {
    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 27))!
    private let pool = ["свет", "тепло", "море", "поле", "ветер", "камень"]

    private func options(
        cardID: String = "card1",
        targetMeanings: [String] = ["свет"],
        pool meanings: [String] = ["свет", "тепло", "море", "поле", "ветер", "камень"]
    ) -> [String] {
        ChoiceDistractorProvider.options(
            for: cardID,
            targetMeanings: targetMeanings,
            pool: meanings,
            date: date
        )
    }

    func testSameInputsProduceSameOutput() {
        XCTAssertEqual(options(), options())
    }

    func testReturnsRequestedCountWhenPoolAllows() {
        XCTAssertEqual(options().count, 3)
        XCTAssertEqual(options(pool: ["тепло", "море", "поле"]).count, 3)
        XCTAssertEqual(
            ChoiceDistractorProvider.options(
                for: "card1", targetMeanings: ["свет"], pool: pool, date: date, count: 5
            ).count,
            5
        )
    }

    func testOptionsAreUnique() {
        let selected = options(pool: ["Свет", "свет", "ТЕПЛО", "тепло", "море", "поле"])
        XCTAssertEqual(Set(selected.map(MeaningMatcher.normalized)).count, selected.count)
    }

    func testPoolIsDeduplicatedByNormalizedForm() {
        let selected = options(pool: ["ТЕПЛО", "тепло", "море", "поле", "свет"])
        XCTAssertEqual(selected.count, 3)
        XCTAssertEqual(Set(selected.map(MeaningMatcher.normalized)), Set(["тепло", "море", "поле"]))
    }

    func testTargetMeaningsNeverAppear() {
        let selected = options(targetMeanings: ["свет"], pool: ["СВЕТ", "свет", "тепло", "море", "поле", "ветер"])
        let normalizedSelection = selected.map(MeaningMatcher.normalized)
        XCTAssertFalse(normalizedSelection.contains("свет"))
    }

    func testTargetMeaningsExcludedEvenWithYoAndCase() {
        let selected = options(targetMeanings: ["Ёлка"], pool: ["ёлка", "ЕЛКА", "свет", "тепло", "море", "поле"])
        let normalizedSelection = Set(selected.map(MeaningMatcher.normalized))
        XCTAssertFalse(normalizedSelection.contains("елка"))
    }

    func testOnlyTargetsAreExcluded() {
        let selected = ChoiceDistractorProvider.options(
            for: "card1",
            targetMeanings: ["свет"],
            pool: ["свет", "светлость", "тепло", "море"],
            date: date,
            count: 3
        )
        XCTAssertTrue(selected.map(MeaningMatcher.normalized).contains("светлость"))
        XCTAssertFalse(selected.map(MeaningMatcher.normalized).contains("свет"))
    }

    func testSmallPoolReturnsFewerOptions() {
        XCTAssertEqual(options(pool: ["тепло", "море"]).count, 2)
        XCTAssertEqual(options(pool: ["тепло"]).count, 1)
    }

    func testEmptyPoolReturnsNoOptions() {
        XCTAssertTrue(options(pool: []).isEmpty)
    }

    func testPoolItemsThatNormalizeToEmptyAreSkipped() {
        XCTAssertEqual(options(pool: ["!!!", "???", "тепло"]).count, 1)
    }

    func testCountZeroReturnsNoOptions() {
        XCTAssertTrue(
            ChoiceDistractorProvider.options(
                for: "card1", targetMeanings: ["свет"], pool: pool, date: date, count: 0
            ).isEmpty
        )
    }
}
