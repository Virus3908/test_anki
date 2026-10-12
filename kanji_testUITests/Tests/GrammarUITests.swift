import XCTest

final class GrammarUITests: UITestCase {
    func testAllFiveLevelsOpenWithRealStatistics() {
        launch()
        openGrammar()
        capture("01-grammar-home")
        for level in ["N5", "N4", "N3", "N2", "N1"] {
            scrollTo("grammar.level.\(level)")
            tap("grammar.level.\(level)", .openDeck, expecting: "grammar.statistics")
            XCTAssertTrue(element("grammar.learn").exists)
            XCTAssertTrue(element("grammar.review").exists)
            if level == "N5" { capture("02-n5-rule-list") }
            tap(ID.Preview.back, .backToStart, expecting: "grammar.total")
        }
    }

    func testLessonExercisesResultContinuationAndUndo() {
        launch()
        openWaLesson()
        capture("03-rule-explanation")
        XCTAssertTrue(element("grammar.lesson.explanation").exists)
        scrollTo("grammar.furigana")
        XCTAssertTrue(element("grammar.example").exists)
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        capture("04-exercise-before-answer")
        for index in 0..<3 {
            answer(correct: true)
            if index == 0 { capture("05-correct-answer") }
            tap("grammar.training.next", .revealCard,
                expecting: index < 2 ? "grammar.training.next" : "grammar.training.saved")
        }
        capture("07-lesson-result")
        XCTAssertTrue(element("grammar.training.result").label.contains("3 из 3"))
        tap("grammar.training.continue", .rateCard, expecting: "grammar.training.next")
        tap("grammar.training.undo", .rateCard, expecting: "grammar.training.begin")
        tap(ID.Preview.back, .exitTraining, expecting: "grammar.practice")
    }

    func testWrongAnswersOnCompactPhoneWithLargeText() {
        launch(largeText: true)
        XCTAssertLessThanOrEqual(app.frame.width, 430, "CI must use an installed compact iPhone")
        openWaLesson()
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        for index in 0..<3 {
            answer(correct: false)
            if index == 0 { capture("06-incorrect-answer-large-text") }
            tap("grammar.training.next", .revealCard,
                expecting: index < 2 ? "grammar.training.next" : "grammar.training.saved")
        }
        XCTAssertTrue(element("grammar.training.result").label.contains("0 из 3"))
        capture("08-lesson-result-large-text")
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
        element("grammar.related.katawara").tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "〜かたわら")).firstMatch.waitForExistence(timeout: 5))
    }

    private func openGrammar() {
        for _ in 0..<5 where !element("start.section.grammar").isHittable {
            element("start.sectionSwitcher").swipeLeft()
        }
        tap("start.section.grammar", .switchSection, expecting: "grammar.total")
    }

    private func openWaLesson() {
        openGrammar()
        tap("grammar.level.N5", .openDeck, expecting: "grammar.statistics")
        scrollTo("grammar.rule.wa")
        tap("grammar.rule.wa", .openDeck, expecting: "grammar.lesson.title")
    }

    private func answer(correct: Bool) {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grammar.option."))
        let predicate = NSPredicate(format: correct ? "identifier BEGINSWITH %@" : "NOT (identifier BEGINSWITH %@)", "grammar.option.wa")
        let option = query.matching(predicate).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        for _ in 0..<8 where !option.isHittable { app.swipeUp() }
        XCTAssertTrue(option.isHittable)
        step(.revealCard, until: element("grammar.training.feedback")) { option.tap() }
        XCTAssertEqual(option.value as? String, correct ? "correct" : "selectedIncorrect")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "grammar-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollTo(_ identifier: String) {
        for _ in 0..<10 where !element(identifier).isHittable { app.swipeUp() }
        XCTAssertTrue(element(identifier).isHittable, "Element must be reachable: \(identifier)")
    }
}
