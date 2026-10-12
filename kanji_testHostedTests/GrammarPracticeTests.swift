import XCTest
@testable import kanji_test

@MainActor
final class GrammarPracticeTests: XCTestCase {
    func testAnswerIDsNeverDependOnOptionPositionAndUnknownOptionIsWrong() {
        let exercise = fixture()
        XCTAssertTrue(exercise.accepts("te-hoshii"))
        XCTAssertFalse(exercise.accepts("tai"))
        XCTAssertFalse(exercise.accepts("unknown"))
        let original = Set(exercise.options.map(\.id))
        for seed in ["a", "b", "c", "d"] {
            let ordered = GrammarExerciseSelection.ordered(exercise.options, seed: seed)
            XCTAssertEqual(Set(ordered.map(\.id)), original)
            XCTAssertEqual(ordered.filter { exercise.accepts($0.id) }.map(\.id), ["te-hoshii"])
        }
    }

    func testDeterministicRotationAndDifferentSeedsPreserveEveryExercise() {
        let values = Array(0..<20)
        let first = GrammarExerciseSelection.ordered(values, seed: "first")
        XCTAssertEqual(first, GrammarExerciseSelection.ordered(values, seed: "first"))
        XCTAssertNotEqual(first, GrammarExerciseSelection.ordered(values, seed: "second"))
        XCTAssertEqual(Set(first), Set(values))
    }

    func testEveryRuleHasRealSourceRecallPromptsAndCannotFinishBeforeReveal() async throws {
        let rules = try await GrammarDataLoader.shared.allRules()
        for rule in rules {
            let practice = GrammarPracticeViewModel(rule: rule, seed: "fixture", freePractice: true)
            XCTAssertTrue(practice.isSelfAssessment)
            XCTAssertEqual(practice.count, 3)
            XCTAssertEqual(Set(practice.recallPrompts.map(\.id)).count, 3)
            XCTAssertTrue(practice.recallPrompts.allSatisfy { !$0.cue.isEmpty && !$0.sourceAnswer.isEmpty })
            practice.next()
            XCTAssertEqual(practice.position, 0)
            for _ in 0..<3 { practice.reveal(); practice.next() }
            XCTAssertTrue(practice.isComplete)
            XCTAssertTrue(practice.results.isEmpty, "Self-assessment must not fabricate a correct answer")
        }
    }

    func testEveryTypedKindDecodesWithAnIdentityBasedKey() throws {
        for kind in GrammarExerciseKind.allCases {
            let exercise = fixture(kind: kind)
            let decoded = try JSONDecoder().decode(GrammarExercise.self, from: JSONEncoder().encode(exercise))
            XCTAssertEqual(decoded.kind, kind)
            XCTAssertEqual(decoded.acceptedOptionIDs, ["te-hoshii"])
        }
    }

    func testBundledExercisesCheckAnswersAndRejectRepeatedTaps() async throws {
        for rule in try await GrammarDataLoader.shared.allRules() {
            let model = GrammarPracticeViewModel(rule: rule, seed: "fixture")
            XCTAssertFalse(model.isSelfAssessment)
            XCTAssertNil(model.contentError)
            XCTAssertEqual(model.count, 3)
            model.next()
            XCTAssertEqual(model.position, 0)
            for _ in 0..<3 {
                let exercise = try XCTUnwrap(model.currentExercise)
                let correct = try XCTUnwrap(exercise.acceptedOptionIDs.first)
                model.choose("invalid")
                XCTAssertFalse(model.isAnswerVisible)
                model.choose(correct)
                model.choose(correct)
                XCTAssertEqual(model.results.count, model.position + 1)
                XCTAssertTrue(model.results.last?.isCorrect == true)
                model.next()
            }
            XCTAssertTrue(model.isComplete)
            XCTAssertEqual(model.proposedRating, .good)
            model.choose("invalid")
            XCTAssertEqual(model.results.count, 3)
            model.close()
            XCTAssertNil(model.proposedRating)
        }
    }

    func testMalformedExerciseDisablesOnlyItsRuleAndNeverFallsBackToRecall() async throws {
        let rules = try await GrammarDataLoader.shared.rules(.n5)
        let original = try XCTUnwrap(rules.first)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var exercises = try XCTUnwrap(object["exercises"] as? [[String: Any]])
        exercises[0]["acceptedOptionIDs"] = ["nonexistent-option"]
        object["exercises"] = exercises
        let rule = try JSONDecoder().decode(GrammarRule.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(rule.pattern, original.pattern)
        XCTAssertEqual(rule.examples.count, original.examples.count)
        let practice = GrammarPracticeViewModel(rule: rule, seed: "bad-content")
        XCTAssertNotNil(practice.contentError)
        XCTAssertFalse(practice.isSelfAssessment)
        XCTAssertFalse(practice.isComplete)
        practice.choose("nonexistent-option"); practice.next()
        XCTAssertTrue(practice.results.isEmpty)
        XCTAssertNil(practice.proposedRating)
    }

    func testLessonRatingPolicyNeverInfersEasyOrIncompleteResults() {
        XCTAssertEqual(GrammarLessonRating.rating(correct: 0, total: 3), .again)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 1, total: 3), .again)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 2, total: 3), .hard)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 3, total: 3), .good)
        XCTAssertNil(GrammarLessonRating.rating(correct: 1, total: 2))
        XCTAssertNil(GrammarLessonRating.rating(correct: 4, total: 3))
    }

    func testWrongAnswersAndAllFourLessonOutcomes() async throws {
        let rules = try await GrammarDataLoader.shared.rules(.n5)
        let rule = try XCTUnwrap(rules.first)
        for correctCount in 0...3 {
            let practice = GrammarPracticeViewModel(rule: rule, seed: "score")
            for index in 0..<3 {
                let exercise = try XCTUnwrap(practice.currentExercise)
                let option = try XCTUnwrap(exercise.options.first { exercise.accepts($0.id) == (index < correctCount) })
                practice.choose(option.id)
                practice.next(); practice.next()
            }
            XCTAssertEqual(practice.correctCount, correctCount)
            XCTAssertEqual(practice.proposedRating, [.again, .again, .hard, .good][correctCount])
            XCTAssertEqual(practice.results.count, 3)
        }
    }

    func testTranslationProtectsJapaneseAndRejectsCorruptTokens() {
        let source = "Verb + てほしい expresses a wish."
        let protected = GrammarTranslationProjection.protect(source)
        XCTAssertFalse(protected.text.contains("てほしい"))
        XCTAssertEqual(GrammarTranslationProjection.restore(protected.text, original: source), source)
        XCTAssertEqual(GrammarTranslationProjection.restore("Повреждённый перевод", original: source), source)
    }

    private func fixture(kind: GrammarExerciseKind = .chooseConstruction) -> GrammarExercise {
        // Test-only answer-key fixture. It is not bundled learning content and makes no review claim.
        GrammarExercise(id: "test-only", ruleID: "te-hoshii", kind: kind,
            promptRU: "Как выразить желание, чтобы другой человек совершил действие?",
            options: [.init(id: "tai", text: "〜たい", feedbackRU: "Выражает желание самого действующего лица."),
                      .init(id: "te-hoshii", text: "〜てほしい", feedbackRU: nil)],
            acceptedOptionIDs: ["te-hoshii"], explanationRU: "〜てほしい выражает желание относительно действия другого лица.",
            difficulty: 1, reviewer: "test fixture; not published")
    }
}
