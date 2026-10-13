import XCTest
@testable import kanji_test

@MainActor
final class GrammarPracticeTests: XCTestCase {
    func testAnswerIDsNeverDependOnOptionPositionAndUnknownOptionIsWrong() {
        let exercise = fixture()
        XCTAssertTrue(exercise.accepts("yes")); XCTAssertFalse(exercise.accepts("no"))
        XCTAssertFalse(exercise.accepts("unknown"))
        for seed in ["a", "b", "c", "d"] {
            XCTAssertEqual(Set(GrammarExerciseSelection.ordered(exercise.options, seed: seed).map(\.id)), Set(exercise.options.map(\.id)))
        }
    }
    func testDeterministicRotationAndDifferentSeedsPreserveEveryExercise() {
        let values = Array(0..<20)
        XCTAssertEqual(GrammarExerciseSelection.ordered(values, seed: "first"), GrammarExerciseSelection.ordered(values, seed: "first"))
        XCTAssertNotEqual(GrammarExerciseSelection.ordered(values, seed: "first"), GrammarExerciseSelection.ordered(values, seed: "second"))
        XCTAssertEqual(Set(GrammarExerciseSelection.ordered(values, seed: "second")), Set(values))
    }
    func testEveryRuleHasRealSourceRecallPromptsAndCannotFinishBeforeReveal() async throws {
        for rule in try await GrammarDataLoader.shared.allRules() {
            let practice = GrammarPracticeViewModel(rule: rule, seed: "fixture", freePractice: true)
            XCTAssertEqual(practice.count, 3)
            XCTAssertTrue(practice.recallPrompts.allSatisfy { !$0.cue.isEmpty && !$0.sourceAnswer.isEmpty })
            practice.next(); XCTAssertEqual(practice.position, 0)
            for _ in 0..<3 { practice.reveal(); practice.next() }
            XCTAssertTrue(practice.isComplete); XCTAssertTrue(practice.results.isEmpty)
            XCTAssertNil(practice.proposedRating)
        }
    }
    func testEveryTypedKindDecodesWithAnIdentityBasedKey() throws {
        for kind in GrammarExerciseKind.allCases {
            let exercise = fixture(kind: kind)
            let decoded = try JSONDecoder().decode(GrammarExercise.self, from: JSONEncoder().encode(exercise))
            XCTAssertEqual(decoded.kind, kind); XCTAssertEqual(decoded.acceptedOptionIDs, ["yes"])
        }
    }
    func testBundledExercisesCheckAnswersAndRejectRepeatedTaps() async throws {
        for rule in try await GrammarDataLoader.shared.allRules() where rule.teaching != nil {
            let model = GrammarPracticeViewModel(rule: rule, seed: "fixture")
            XCTAssertNil(model.contentError); XCTAssertTrue((4...6).contains(model.count))
            model.next(); XCTAssertEqual(model.position, 0)
            let originalCount = model.count
            while !model.isComplete {
                let exercise = try XCTUnwrap(model.currentExercise)
                model.choose("invalid"); XCTAssertFalse(model.isAnswerVisible)
                answer(model, exercise: exercise, correct: true)
                answer(model, exercise: exercise, correct: true)
                XCTAssertEqual(model.results.count, model.position + 1)
                model.next()
            }
            XCTAssertEqual(model.results.count, originalCount)
            XCTAssertEqual(model.proposedRating, .good)
            model.close(); XCTAssertNil(model.proposedRating)
        }
    }
    func testMalformedExerciseDisablesOnlyItsRuleAndNeverFallsBackToRecall() async throws {
        let original = try await loadRule("tai")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var exercises = try XCTUnwrap(object["exercises"] as? [[String: Any]])
        exercises[0]["acceptedOptionIDs"] = ["nonexistent-option"]
        object["exercises"] = exercises
        let rule = try JSONDecoder().decode(GrammarRule.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(rule.examples.count, original.examples.count)
        let practice = GrammarPracticeViewModel(rule: rule, seed: "bad-content")
        XCTAssertNotNil(practice.contentError); XCTAssertFalse(practice.isSelfAssessment)
        practice.choose("nonexistent-option"); practice.next()
        XCTAssertTrue(practice.results.isEmpty); XCTAssertNil(practice.proposedRating)
    }
    func testLessonRatingPolicyNeverInfersEasyOrIncompleteResults() {
        XCTAssertEqual(GrammarLessonRating.rating(correct: 0, total: 3), .again)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 1, total: 3), .again)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 2, total: 3), .hard)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 3, total: 3), .good)
        XCTAssertEqual(GrammarLessonRating.rating(correct: 3, total: 3, hints: 1), .hard)
        XCTAssertNil(GrammarLessonRating.rating(correct: 1, total: 2))
        XCTAssertNil(GrammarLessonRating.rating(correct: 4, total: 3))
        XCTAssertNil(GrammarLessonRating.rating(correct: 3, total: 3, hints: 4))
    }
    func testWrongAnswersAndAllFourLessonOutcomes() async throws {
        let rule = try await loadRule("tai")
        for correct in [false, true] {
            let model = GrammarPracticeViewModel(rule: rule, seed: "score")
            while !model.isComplete {
                let exercise = try XCTUnwrap(model.currentExercise)
                answer(model, exercise: exercise, correct: correct); model.next(); model.next()
            }
            XCTAssertEqual(model.correctCount, correct ? model.count : 0)
            XCTAssertEqual(model.proposedRating, correct ? .good : .again)
            XCTAssertLessThanOrEqual(model.count, GrammarPracticeViewModel.maximumCount)
        }
    }
    func testFirstLessonAndReviewRotateSkillsAndRespectDifficulty() async throws {
        let rule = try await loadRule("gatera")
        let first = GrammarPracticeViewModel(rule: rule, seed: "gatera:0")
        XCTAssertFalse(first.isLessonRead); XCTAssertEqual(first.currentExercise?.kind, .fillBlank)
        XCTAssertTrue((4...6).contains(first.count))
        let review = GrammarPracticeViewModel(rule: rule, seed: "gatera:4", isReview: true, attempt: 4)
        XCTAssertTrue(review.isLessonRead); XCTAssertTrue((3...5).contains(review.count))
        XCTAssertNotEqual(first.exercises.map(\.id), review.exercises.map(\.id))
        for model in [first, review] {
            XCTAssertEqual(Set(model.exercises.map(\.id)).count, model.count)
            XCTAssertGreaterThanOrEqual(Set(model.exercises.map(\.kind)).count, 3)
        }
        let difficult = rule.withExercises([fixture(id: "hard", difficulty: 3), fixture(id: "easy", difficulty: 1), fixture(id: "mid", difficulty: 2)])
        let beginner = GrammarPracticeViewModel(rule: difficult, seed: "level")
        XCTAssertEqual(beginner.currentExercise?.difficulty, 1)
    }
    func testAdditionalTaskTargetsSameAspectAndHintsReduceRating() async throws {
        let rule = try await loadRule("tai")
        let model = GrammarPracticeViewModel(rule: rule, seed: "adapt")
        let initial = model.count
        let current = try XCTUnwrap(model.currentExercise)
        model.useHint(); model.useHint()
        answer(model, exercise: current, correct: true); model.next()
        XCTAssertEqual(model.currentExercise?.aspect, current.aspect)
        XCTAssertNotEqual(model.currentExercise?.id, current.id)
        XCTAssertEqual(model.count, initial + 1)
        while !model.isComplete {
            answer(model, exercise: try XCTUnwrap(model.currentExercise), correct: true); model.next()
        }
        XCTAssertEqual(model.results.filter(\.usedHint).count, 1)
        XCTAssertEqual(model.proposedRating, .hard)
        XCTAssertFalse(model.weakAspects.isEmpty)
    }
    func testConfidentReviewCanFinishAfterThreeDifferentSkills() async throws {
        let original = try await loadRule("gatera")
        let exercises = [fixture(kind: .fillBlank, id: "form"), fixture(kind: .chooseContext, id: "context"),
            fixture(kind: .transformSentence, id: "apply"), fixture(kind: .assembleSentence, id: "extra"),
            fixture(kind: .distinguishMeaning, id: "meaning")]
        let rule = original.withExercises(exercises)
        let model = GrammarPracticeViewModel(rule: rule, seed: "confident", isReview: true, previousRating: .good)
        XCTAssertEqual(model.count, 5)
        for _ in 0..<3 { answer(model, exercise: try XCTUnwrap(model.currentExercise), correct: true); model.next() }
        XCTAssertTrue(model.isComplete); XCTAssertEqual(model.count, 3)
        XCTAssertEqual(model.proposedRating, .good)
        let relearning = GrammarPracticeViewModel(rule: rule, seed: "confident", isReview: true, previousRating: .again)
        for _ in 0..<3 { answer(relearning, exercise: try XCTUnwrap(relearning.currentExercise), correct: true); relearning.next() }
        XCTAssertFalse(relearning.isComplete)
    }

    func testMultipleAcceptedAnswersAndAssemblyOrdersAreExplicit() {
        var exercise = fixture()
        XCTAssertFalse(exercise.accepts(order: ["yes", "no"]))
        exercise = GrammarExercise(id: "ambiguous", ruleID: "gatera", kind: .chooseContext, promptRU: "Контекст", options: [
            .init(id: "a", text: "A", feedbackRU: nil), .init(id: "b", text: "B", feedbackRU: nil), .init(id: "c", text: "C", feedbackRU: nil)],
            acceptedOptionIDs: ["a", "b"], explanationRU: "Два допустимых ответа", difficulty: 1)
        XCTAssertTrue(exercise.isUsable(for: "gatera")); XCTAssertTrue(exercise.accepts("a")); XCTAssertTrue(exercise.accepts("b"))
        let assembly = fixture(kind: .assembleSentence)
        XCTAssertTrue(assembly.accepts(order: ["yes"]))
        XCTAssertFalse(assembly.accepts(order: ["no", "yes"]))
        XCTAssertFalse(assembly.accepts(order: ["yes", "yes"]))
    }
    func testSaveGatePreventsDuplicateCompletionAndAllowsFailureRetry() async throws {
        let rule = try await loadRule("tai")
        let model = GrammarPracticeViewModel(rule: rule, seed: "saving")
        XCTAssertNil(model.beginSaving())
        while !model.isComplete { answer(model, exercise: try XCTUnwrap(model.currentExercise), correct: true); model.next() }
        XCTAssertEqual(model.beginSaving(), .good); XCTAssertNil(model.beginSaving())
        model.finishSaving(success: false)
        XCTAssertEqual(model.beginSaving(), .good)
        model.finishSaving(success: true)
        XCTAssertNil(model.beginSaving()); XCTAssertNil(model.proposedRating)
    }
    func testEveryRequiredApplicationKindHasOfflineMaterialAcrossAllLevels() async throws {
        let all = try await GrammarDataLoader.shared.allRules()
        XCTAssertEqual(Set(all.filter { $0.teaching != nil }.map(\.level)), Set(GrammarLevel.allCases))
        let exercises = all.flatMap { $0.exercises ?? [] }
        for kind in [GrammarExerciseKind.fillBlank, .transformSentence, .assembleSentence, .chooseContext, .correctError, .distinguishMeaning, .understandSentence] {
            XCTAssertTrue(exercises.contains { $0.kind == kind && $0.eligibleForPractice })
        }
        for rule in all where rule.teaching == nil {
            XCTAssertNotNil(GrammarPracticeViewModel(rule: rule, seed: "offline").contentError)
        }
    }
    func testTranslationProtectsJapaneseAndRejectsCorruptTokens() {
        let source = "Verb + てほしい expresses a wish."
        let protected = GrammarTranslationProjection.protect(source)
        XCTAssertFalse(protected.text.contains("てほしい"))
        XCTAssertEqual(GrammarTranslationProjection.restore(protected.text, original: source), source)
        XCTAssertEqual(GrammarTranslationProjection.restore("Повреждённый перевод", original: source), source)
    }
    private func loadRule(_ id: String) async throws -> GrammarRule {
        let value = try await GrammarDataLoader.shared.rule(id)
        return try XCTUnwrap(value)
    }
    private func answer(_ model: GrammarPracticeViewModel, exercise: GrammarExercise, correct: Bool) {
        if exercise.kind == .assembleSentence {
            let order = correct ? exercise.acceptedOrders!.first! : [exercise.options.last!.id]
            for id in order { model.toggleElement(id) }
            model.checkAssembly()
        } else if let option = exercise.options.first(where: { exercise.accepts($0.id) == correct }) { model.choose(option.id) }
    }
    private func fixture(kind: GrammarExerciseKind = .fillBlank, id: String = "test-only", difficulty: Int = 1) -> GrammarExercise {
        GrammarExercise(id: id, ruleID: "gatera", kind: kind, promptRU: id, options: [
            .init(id: "yes", text: "Yes", feedbackRU: nil), .init(id: "no", text: "No", feedbackRU: nil)],
            acceptedOptionIDs: ["yes"], explanationRU: "Test fixture", difficulty: difficulty,
            provenance: .init(commit: "test", sourceRuleID: "gatera", exampleIndex: nil, method: "fixture", status: .automaticallyChecked),
            aspect: "fixture", acceptedOrders: kind == .assembleSentence ? [["yes"]] : nil, isScored: true)
    }
}
