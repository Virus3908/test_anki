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
        XCTAssertFalse(element("grammar.lesson.explanation").exists)
        scrollTo("grammar.lesson.details")
        element("grammar.lesson.details").tap()
        XCTAssertTrue(element("grammar.lesson.explanation").exists)
        scrollTo("grammar.lesson.examples")
        element("grammar.lesson.examples").tap()
        scrollTo("grammar.furigana")
        XCTAssertTrue(element("grammar.example").exists)
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        capture("04-exercise-before-answer")
        var answered = 0
        while !element("grammar.training.saved").exists && answered < 8 {
            answer(correct: true)
            if answered == 0 { capture("05-correct-answer") }
            advanceQuestion()
            answered += 1
        }
        XCTAssertTrue(element("grammar.training.saved").waitForExistence(timeout: 10))
        capture("07-lesson-result")
        XCTAssertTrue(element("grammar.training.result").label.contains("5 из 5"))
        tap("grammar.training.continue", .rateCard, expecting: "grammar.training.begin")
        tap("grammar.training.undo", .rateCard, expecting: "grammar.training.begin")
        tap(ID.Preview.back, .exitTraining, expecting: "grammar.practice")
    }

    func testWrongAnswersOnCompactPhoneWithLargeText() {
        launch(largeText: true)
        XCTAssertLessThanOrEqual(app.frame.width, 430, "CI must use an installed compact iPhone")
        openWaLesson()
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        var answered = 0
        while !element("grammar.training.saved").exists && answered < 8 {
            answer(correct: false)
            if answered == 0 { capture("06-incorrect-answer-large-text") }
            advanceQuestion()
            answered += 1
        }
        XCTAssertTrue(element("grammar.training.saved").waitForExistence(timeout: 10))
        XCTAssertTrue(element("grammar.training.result").label.contains("0 из"))
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
        scrollTo("grammar.rule.relations")
        element("grammar.rule.relations").tap()
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
        scrollTo("grammar.level.N5")
        tap("grammar.level.N5", .openDeck, expecting: "grammar.statistics")
        scrollTo("grammar.rule.wa")
        tap("grammar.rule.wa", .openDeck, expecting: "grammar.lesson.title")
    }

    private func advanceQuestion() {
        let previous = element("grammar.training.prompt").value as? String
        step(.revealCard, until: {
            self.element("grammar.training.saved").exists ||
                (self.element("grammar.training.prompt").exists && self.element("grammar.training.prompt").value as? String != previous)
        }) { element("grammar.training.next").tap() }
    }

    private func answer(correct: Bool) {
        if element("grammar.assembly").exists {
            let ids = correct ? ["0", "1", "2"] : ["0", "3", "2"]
            for id in ids { scrollTo("grammar.element." + id); element("grammar.element." + id).tap() }
            element("grammar.training.next").tap()
            XCTAssertTrue(element("grammar.training.feedback").waitForExistence(timeout: 10))
            capture("09-sentence-assembly")
            return
        }
        let option = element("grammar.option." + (correct ? "0" : "1"))
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        scrollTo(option.identifier)
        step(.revealCard, until: element("grammar.training.feedback")) { option.tap() }
        XCTAssertEqual(option.value as? String, correct ? "correct" : "selectedIncorrect")
    }

    func testTheoryAndExitPreserveUnfinishedAnswers() {
        launch()
        openWaLesson()
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        answer(correct: true)
        tap("grammar.training.theory", .openDeck, expecting: "grammar.lesson.title")
        app.buttons["Закрыть"].tap()
        XCTAssertTrue(element("grammar.training.feedback").waitForExistence(timeout: 5))
        tap(ID.Preview.back, .exitTraining, expecting: "grammar.practice")
        tap("grammar.practice", .startTraining, expecting: "grammar.training.feedback")
        XCTAssertFalse(element("grammar.training.saved").exists)
        XCTAssertFalse(element("grammar.training.begin").exists)
    }

    func testReviewStartsWithPracticeAndRetainsAnswersAfterTheory() {
        launch()
        openWaLesson()
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.next")
        for _ in 0..<5 { answer(correct: true); advanceQuestion() }
        XCTAssertTrue(element("grammar.training.saved").exists)
        tap(ID.Preview.back, .exitTraining, expecting: "grammar.practice")
        tap(ID.Preview.back, .backToStart, expecting: "grammar.review")
        app.buttons["Настройки"].tap()
        XCTAssertTrue(element(ID.Settings.done).waitForExistence(timeout: 5))
        let nextDay = app.buttons["Перейти на следующий учебный день"]
        for _ in 0..<25 where !nextDay.isHittable { app.swipeUp() }
        XCTAssertTrue(nextDay.isHittable)
        nextDay.tap()
        element(ID.Settings.done).tap()
        tap("grammar.review", .startTraining, expecting: "grammar.training.next")
        XCTAssertFalse(element("grammar.training.begin").exists)
        answer(correct: true)
        tap("grammar.training.theory", .openDeck, expecting: "grammar.lesson.title")
        app.buttons["Закрыть"].tap()
        XCTAssertTrue(element("grammar.training.feedback").waitForExistence(timeout: 5))
        capture("10-review-without-required-theory")
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
