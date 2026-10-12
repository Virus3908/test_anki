import XCTest

final class GrammarUITests: UITestCase {
    func testAllFiveLevelsOpenWithRealStatistics() {
        launch()
        tap("start.section.grammar", .switchSection, expecting: "grammar.total")
        for level in ["N5", "N4", "N3", "N2", "N1"] {
            scrollTo("grammar.level.\(level)")
            tap("grammar.level.\(level)", .openDeck, expecting: "grammar.statistics")
            XCTAssertTrue(element("grammar.learn").exists)
            XCTAssertTrue(element("grammar.review").exists)
            XCTAssertTrue(element("grammar.contentStatus").exists)
            step(.backToStart, until: element("grammar.total")) { app.navigationBars.buttons.firstMatch.tap() }
        }
    }

    func testRuleExampleFuriganaAndThreePromptSelfAssessment() {
        launch()
        tap("start.section.grammar", .switchSection, expecting: "grammar.level.N5")
        tap("grammar.level.N5", .openDeck, expecting: "grammar.rule.wa")
        scrollTo("grammar.rule.wa")
        tap("grammar.rule.wa", .openDeck, expecting: "grammar.lesson.title")
        XCTAssertTrue(element("grammar.lesson.explanation").exists)
        app.swipeUp()
        XCTAssertTrue(element("grammar.example").waitForExistence(timeout: 5))
        XCTAssertTrue(element("grammar.furigana").exists)
        // Practice is after examples/attribution; scroll until it can be tapped.
        scrollTo("grammar.practice")
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        scrollTo("grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.reveal")
        for _ in 0..<3 {
            tap("grammar.training.reveal", .revealCard, expecting: "grammar.training.next")
            element("grammar.training.next").tap()
        }
        XCTAssertTrue(element(ID.Training.rateGood).waitForExistence(timeout: 5))
        XCTAssertTrue(element(ID.Training.rateGood).isEnabled)
        XCTAssertTrue(element("grammar.training.exit").exists)
    }

    func testGlobalGrammarSearchOpensFullLessonAndSourceReference() {
        launch()
        tap(ID.Start.search, .openSearch, expecting: ID.Search.field)
        element(ID.Search.field).tap()
        element(ID.Search.field).typeText("gatera")
        let result = element("grammar.searchResult.gatera")
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.tap()
        XCTAssertTrue(element("grammar.lesson.title").waitForExistence(timeout: 5))
        scrollTo("grammar.related.katawara")
        XCTAssertTrue(element("grammar.related.katawara").exists)
        element("grammar.related.katawara").tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "〜かたわら")).firstMatch.waitForExistence(timeout: 5))
    }

    private func scrollTo(_ identifier: String) {
        for _ in 0..<8 where !element(identifier).isHittable { app.swipeUp() }
        XCTAssertTrue(element(identifier).isHittable, "Element must be reachable after scrolling: \(identifier)")
    }
}
