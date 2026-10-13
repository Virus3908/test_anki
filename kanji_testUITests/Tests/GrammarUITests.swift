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
            if level == "N1" { capture("22-n1-rule-list") }
            tap(ID.Preview.back, .backToStart, expecting: "grammar.total")
        }
    }

    func testLessonExercisesResultContinuationAndUndo() {
        launch()
        openWaLesson()
        capture("03-rule-explanation")
        XCTAssertTrue(element("grammar.lesson.card").exists)
        XCTAssertTrue(element("grammar.practice.availability").exists)
        XCTAssertTrue(element("grammar.lesson.card").descendants(matching: .any)
            .matching(identifier: "grammar.lesson.details").firstMatch.exists)
        XCTAssertFalse(element("grammar.lesson.explanation").exists)
        scrollTo("grammar.lesson.details")
        element("grammar.lesson.details").tap()
        XCTAssertTrue(element("grammar.lesson.explanation").exists)
        capture("23-expanded-grammar-explanation")
        scrollTo("grammar.lesson.examples")
        element("grammar.lesson.examples").tap()
        scrollTo("grammar.furigana")
        XCTAssertTrue(element("grammar.example").exists)
        XCTAssertFalse(element("grammar.examples.reload").exists)
        XCTAssertFalse(element("grammar.examples.next").exists)
        let exampleRetry = element("grammar.translation.example.0")
        XCTAssertTrue(exampleRetry.waitForExistence(timeout: 5))
        XCTAssertTrue(exampleRetry.isEnabled)
        let exampleRow = element("study.example.grammar-wa-0")
        let japanese = exampleRow.descendants(matching: .any)
            .matching(identifier: "examples.furigana").firstMatch
        let sourceButton = exampleRow.descendants(matching: .button)
            .matching(identifier: "study.example.source.grammar-wa-0").firstMatch
        XCTAssertTrue(japanese.waitForExistence(timeout: 5))
        XCTAssertTrue(sourceButton.waitForExistence(timeout: 5))
        XCTAssertTrue(exampleRow.frame.contains(japanese.frame))
        XCTAssertTrue(exampleRow.frame.contains(sourceButton.frame))
        XCTAssertFalse(japanese.frame.intersects(sourceButton.frame), "The furigana text and source control must not overlap")
        capture("24-grammar-examples-with-controls")
        capture("28-grammar-furigana-inline-source")
        XCTAssertTrue(element("grammar.practice").exists)
        XCTAssertTrue(element("grammar.practice").isHittable)
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
        tap("grammar.training.continue", .rateCard, expecting: "grammar.training.next")
        tap("grammar.training.undo", .rateCard, expecting: "grammar.training.begin")
        tap(ID.Preview.back, .exitTraining, expecting: "grammar.practice")
    }

    func testGrammarRuleCardInDarkAppearance() {
        launch(darkMode: true)
        openWaLesson()
        XCTAssertTrue(element("grammar.lesson.card").waitForExistence(timeout: 5))
        capture("26-grammar-rule-dark")
    }

    func testGrammarTranslationRetryAndOriginalPopover() {
        launch()
        openWaLesson()
        XCTAssertFalse(element("grammar.translation.meaning").exists, "Authored Russian meaning must not offer machine translation")
        XCTAssertFalse(element("grammar.translation.formation").exists, "Authored Russian formula must not offer machine translation")
        scrollTo("grammar.lesson.details")
        element("grammar.lesson.details").tap()
        let retry = element("grammar.translation.explanation")
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        let original = element("grammar.translation.explanation.original")
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Written は")).firstMatch.waitForExistence(timeout: 5))
        capture("25-grammar-translation-original")
    }

    func testGrammarExampleTranslationRetryAndOriginal() {
        launch()
        openWaLesson()
        scrollTo("grammar.lesson.examples")
        element("grammar.lesson.examples").tap()
        let retry = element("grammar.translation.example.0")
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isEnabled)
        retry.tap()
        let original = element("grammar.translation.example.0.original")
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.tap()
        XCTAssertTrue(app.staticTexts["I am a student."].waitForExistence(timeout: 5))
        capture("27-grammar-example-original")
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
    func testSourceOnlyRuleHasBasicPracticeAndCanFinishWithoutFSRS() {
        launch()
        tap(ID.Start.search, .openSearch, expecting: ID.Search.field)
        element(ID.Search.field).tap(); element(ID.Search.field).typeText("katawara")
        let rule = element("grammar.searchResult.katawara")
        XCTAssertTrue(rule.waitForExistence(timeout: 15)); rule.tap()
        XCTAssertTrue(element("grammar.practice").waitForExistence(timeout: 10))
        XCTAssertTrue(element("grammar.practice").isEnabled)
        capture("19-basic-rule-available")
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.form.answer")
        var count = 0
        while !element("grammar.training.result").exists && count < 8 {
            let previous = element("grammar.training.prompt").value as? String
            element("grammar.form.answer").tap(); element("grammar.form.answer").typeText("another wording")
            tap("grammar.training.next", .revealCard, expecting: "grammar.training.feedback")
            XCTAssertTrue(app.staticTexts["Отличается от образца"].exists)
            if count == 0 { capture("20-basic-original-feedback") }
            step(.revealCard, until: {
                self.element("grammar.training.result").exists ||
                    (self.element("grammar.training.prompt").value as? String != previous)
            }) { element("grammar.training.next").tap() }
            count += 1
        }
        XCTAssertTrue(element("grammar.training.result").waitForExistence(timeout: 10))
        XCTAssertFalse(element("grammar.training.saved").exists)
        XCTAssertEqual(element("grammar.training.continue").label, "Готово")
        capture("21-basic-result-without-rating")
        tap("grammar.training.continue", .exitTraining, expecting: "grammar.practice")
    }

    func testIndependentFormInputAndWrongAnswerExplanation() {
        launch()
        tap(ID.Start.search, .openSearch, expecting: ID.Search.field)
        element(ID.Search.field).tap()
        element(ID.Search.field).typeText("tai")
        let rule = element("grammar.searchResult.tai")
        XCTAssertTrue(rule.waitForExistence(timeout: 15)); rule.tap()
        XCTAssertTrue(element("grammar.lesson.title").waitForExistence(timeout: 5))
        capture("11-tai-short-explanation")
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.form.answer")
        capture("12-independent-conjugation")
        let field = element("grammar.form.answer")
        field.tap(); field.typeText("wrong")
        tap("grammar.training.next", .revealCard, expecting: "grammar.training.feedback")
        XCTAssertTrue(app.staticTexts["Отличается от образца"].exists)
        capture("13-conjugation-error-explanation")
        tap("grammar.training.theory", .openDeck, expecting: "grammar.lesson.title")
        app.buttons["Закрыть"].tap()
        XCTAssertTrue(element("grammar.training.feedback").waitForExistence(timeout: 5))
        XCTAssertEqual(element("grammar.form.answer").value as? String, "wrong")
    }

    private func openGrammar() {
        for _ in 0..<5 where !element("start.section.grammar").isHittable {
            element("start.sectionSwitcher").swipeLeft()
        }
        tap("start.section.grammar", .switchSection, expecting: "grammar.total")
    }
    func testMixedQuestionsIntroductionsFuriganaAndSessionResult() {
        launch()
        openGrammar()
        scrollTo("grammar.level.N5")
        tap("grammar.level.N5", .openDeck, expecting: "grammar.statistics")
        tap("grammar.learn", .startTraining, expecting: "grammar.training.begin")
        capture("14-mixed-first-introduction")
        var ids: [String] = []
        var count = 0
        while !element("grammar.mixed.result").exists && count < 32 {
            if element("grammar.training.begin").exists {
                tap("grammar.training.begin", .startTraining, expecting: "grammar.training.prompt")
            }
            let prompt = element("grammar.training.prompt")
            XCTAssertTrue(prompt.waitForExistence(timeout: 10))
            let id = prompt.value as? String ?? ""
            ids.append(id.components(separatedBy: ":").first ?? "")
            XCTAssertFalse(element("grammar.lesson.title").exists)
            if count == 0 { capture("15-mixed-exercise-furigana") }
            if element("grammar.form.answer").exists {
                element("grammar.form.answer").tap()
                element("grammar.form.answer").typeText("wrong")
                tap("grammar.training.next", .revealCard, expecting: "grammar.training.feedback")
            } else if element("grammar.assembly").exists {
                // The test deliberately submits an incomplete order to exercise remediation.
                scrollTo("grammar.element.0"); element("grammar.element.0").tap()
                tap("grammar.training.next", .revealCard, expecting: "grammar.training.feedback")
            } else {
                scrollTo("grammar.option.1")
                tap("grammar.option.1", .revealCard, expecting: "grammar.training.feedback")
            }
            if count == 0 { capture("16-mixed-wrong-answer") }
            scrollTo("grammar.training.next")
            step(.revealCard, until: {
                self.element("grammar.mixed.result").exists || self.element("grammar.training.begin").exists ||
                    (self.element("grammar.training.prompt").value as? String != id)
            }) { element("grammar.training.next").tap() }
            count += 1
        }
        XCTAssertTrue(element("grammar.mixed.result").waitForExistence(timeout: 10))
        XCTAssertGreaterThan(Set(ids).count, 1)
        XCTAssertNotEqual(ids.first, ids.dropFirst().first)
        XCTAssertTrue(ids.dropFirst(2).contains(ids.first ?? ""))
        capture("17-mixed-session-result")
    }
    func testExerciseFuriganaFollowsExistingToggle() {
        launch()
        openWaLesson()
        scrollTo("grammar.lesson.examples")
        element("grammar.lesson.examples").tap()
        scrollTo("grammar.furigana")
        let toggle = element("grammar.furigana")
        toggle.tap()
        tap("grammar.practice", .startTraining, expecting: "grammar.training.begin")
        tap("grammar.training.begin", .startTraining, expecting: "grammar.training.prompt")
        XCTAssertEqual(element("grammar.training.japanese").value as? String, "plain")
        tap("grammar.training.theory", .openDeck, expecting: "grammar.lesson.title")
        scrollTo("grammar.lesson.examples")
        element("grammar.lesson.examples").tap()
        scrollTo("grammar.furigana"); element("grammar.furigana").tap()
        app.buttons["Закрыть"].tap()
        XCTAssertTrue(element("grammar.training.japanese").waitForExistence(timeout: 5))
        XCTAssertEqual(element("grammar.training.japanese").value as? String, "furigana")
        capture("18-exercise-ruby-enabled")
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
