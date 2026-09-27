import XCTest
@testable import kanji_test

final class MeaningMatcherTests: XCTestCase {
    func testExactMatch() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "свет", meanings: ["свет"]), .exact)
    }

    func testCaseInsensitiveExact() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "СВЕТ", meanings: ["свет"]), .exact)
    }

    func testYoEquivalence() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "Ёлка", meanings: ["елка"]), .exact)
        XCTAssertEqual(MeaningMatcher.outcome(for: "елка", meanings: ["Ёлка"]), .exact)
    }

    func testPunctuationIgnored() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "свет,", meanings: ["свет"]), .exact)
        XCTAssertEqual(MeaningMatcher.outcome(for: "свет!", meanings: ["свет"]), .exact)
    }

    func testWhitespaceCollapsed() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "  свет   и    тепло ", meanings: ["свет и тепло"]), .exact)
    }

    func testOneCharTypoIsNearMiss() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "теплоо", meanings: ["тепло"]), .nearMiss)
    }

    func testTwoCharDifferenceIsNearMiss() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "пагада", meanings: ["погода"]), .nearMiss)
    }

    func testThreeCharDifferenceIsNone() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "пааада", meanings: ["погода"]), .none)
    }

    func testShortMeaningNeverNearMiss() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "дам", meanings: ["дом"]), .none)
    }

    func testAnyOfMultipleMeaningsMatches() {
        let meanings = ["свет", "яркость"]
        XCTAssertEqual(MeaningMatcher.outcome(for: "яркость", meanings: meanings), .exact)
        XCTAssertEqual(MeaningMatcher.outcome(for: "яркоссть", meanings: meanings), .nearMiss)
    }

    func testBlankInputIsNone() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "", meanings: ["свет"]), .none)
        XCTAssertEqual(MeaningMatcher.outcome(for: "   ", meanings: ["свет"]), .none)
    }

    func testEmptyMeaningsIsNone() {
        XCTAssertEqual(MeaningMatcher.outcome(for: "свет", meanings: []), .none)
    }

    func testLevenshteinBasics() {
        XCTAssertEqual(MeaningMatcher.levenshtein("кот", "кот"), 0)
        XCTAssertEqual(MeaningMatcher.levenshtein("кот", "код"), 1)
        XCTAssertEqual(MeaningMatcher.levenshtein("", "аб"), 2)
        XCTAssertEqual(MeaningMatcher.levenshtein("аб", ""), 2)
        XCTAssertEqual(MeaningMatcher.levenshtein("пагада", "погода"), 2)
    }

    func testNormalizedForm() {
        XCTAssertEqual(MeaningMatcher.normalized("  Свет, Ёлка!  "), "свет елка")
        XCTAssertEqual(MeaningMatcher.normalized("СВЕТ"), "свет")
        XCTAssertEqual(MeaningMatcher.normalized("!!!"), "")
    }
}
