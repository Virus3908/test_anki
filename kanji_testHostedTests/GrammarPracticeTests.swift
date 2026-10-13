import XCTest
@testable import kanji_test

@MainActor
final class GrammarPracticeTests: XCTestCase {
    private func sentenceExercise(_ sentence: String) -> GrammarExercise {
        GrammarExercise(id: "normalization", ruleID: "tai", kind: .restoreSentence,
            promptRU: "Восстанови пример", options: [.init(id: "source", text: sentence, feedbackRU: nil)],
            acceptedOptionIDs: ["source"], explanationRU: "Сравни с образцом", difficulty: 1, isScored: false)
    }
    func testSentenceNormalizationAcceptsTerminalPeriodsWhitespaceAndNFC() {
        let exercise = sentenceExercise("日本に行きたいです。")
        for text in ["日本に行きたいです", "日本に行きたいです.", " \n日本 に 行きたいです。\t", "日本　に行きたいです"] {
            XCTAssertEqual(GrammarAnswerValidator.assess(text, for: exercise), .correct)
        }
        XCTAssertTrue(GrammarAnswerValidator.accepts("は\u{3099}らを見る", for: sentenceExercise("ばらを見る。")))
        XCTAssertFalse(GrammarAnswerValidator.accepts("ABを見る", for: sentenceExercise("A Bを見る。")))
        XCTAssertFalse(GrammarAnswerValidator.accepts("Ａを見る", for: sentenceExercise("Aを見る。")))
        XCTAssertFalse(GrammarAnswerValidator.accepts("日本に行きたいです...", for: exercise))
        var punctuationTask = exercise
        punctuationTask.testsPunctuation = true
        XCTAssertFalse(GrammarAnswerValidator.accepts("日本に行きたいです", for: punctuationTask))
        XCTAssertFalse(GrammarAnswerValidator.accepts("日本に行きたいです.", for: punctuationTask))
    }
    func testSentenceMismatchNeverProvesGrammarErrorOrAcceptsChangedGrammar() {
        for (source, answer) in [
            ("日本に行きたいです。", "日本に行きたかったです。"),
            ("日本に行きたいです。", "日本に行きたくないです。"),
            ("友達に来てほしいです。", "友達を来てほしいです。"),
            ("日本に行きたいです。", "日本に行きたい。")
        ] {
            XCTAssertFalse(GrammarAnswerValidator.accepts(answer, for: sentenceExercise(source)))
            XCTAssertEqual(GrammarAnswerValidator.assess(answer, for: sentenceExercise(source)), .differsFromSample)
        }
    }
    func testExplicitSentenceAlternativesAreCheckedIndividuallyAndDecode() throws {
        var exercise = sentenceExercise("友達にこの本を読んでほしいです。")
        exercise.acceptedAnswers = ["この本を友達に読んでほしいです。"]
        let decoded = try JSONDecoder().decode(GrammarExercise.self, from: JSONEncoder().encode(exercise))
        XCTAssertTrue(GrammarAnswerValidator.accepts("この本を友達に読んでほしいです", for: decoded))
        XCTAssertTrue(GrammarAnswerValidator.accepts(exercise.correctAnswer, for: decoded))
        XCTAssertFalse(GrammarAnswerValidator.accepts("この本に友達を読んでほしいです", for: decoded))
    }
    func testUnverifiedFreeInputCannotProduceFSRSRating() async throws {
        let rule = try await loadRule("tai")
        let exercise = try XCTUnwrap(rule.exercises?.first { $0.kind == .formProduction })
        XCTAssertEqual(GrammarAnswerValidator.assess("別の言い方", for: exercise), .differsFromSample)
        let rejected = try XCTUnwrap(exercise.options.first { !exercise.accepts($0.id) && $0.feedbackRU?.isEmpty == false })
        XCTAssertEqual(GrammarAnswerValidator.assess(rejected.text, for: exercise), .incorrectForm)
        let exercises = [fixture(id: "a"), fixture(id: "b"), fixture(id: "c")]
        var results = exercises.map { GrammarExerciseResult(exerciseID: $0.id, optionID: "yes", isCorrect: true) }
        results[0] = .init(exerciseID: "a", optionID: "unverified", isCorrect: false, assessment: .differsFromSample)
        XCTAssertNil(GrammarLessonRating.rating(results: results, exercises: exercises))
    }
    func testUnknownFreeFormDoesNotDiagnoseWeakSkillOrAddErrorRemediation() async throws {
        let model = GrammarPracticeViewModel(rule: try await loadRule("tai"), seed: "unknown-form")
        XCTAssertEqual(model.currentExercise?.kind, .formProduction)
        let count = model.count
        model.textAnswer = "別の言い方"; model.checkForm()
        XCTAssertEqual(model.results.last?.assessment, .differsFromSample)
        XCTAssertFalse(model.results.last?.hasVerifiedError == true)
        XCTAssertTrue(model.weakAspects.isEmpty)
        XCTAssertEqual(model.count, count)
        model.next()
        while !model.isComplete {
            answer(model, exercise: try XCTUnwrap(model.currentExercise), correct: true); model.next()
        }
        XCTAssertNil(model.proposedRating)
    }
    func testUnlistedAssemblyOrderIsUnverifiedInsteadOfGrammarError() async throws {
        let rule = try await loadRule("te-hoshii")
        let exercise = try XCTUnwrap(rule.exercises?.first { $0.kind == .assembleSentence })
        let model = GrammarPracticeViewModel(rule: rule.withExercises([exercise]), seed: "order")
        let unknown = Array(try XCTUnwrap(exercise.acceptedOrders?.first).reversed())
        XCTAssertFalse(exercise.accepts(order: unknown))
        for id in unknown { model.toggleElement(id) }
        model.checkAssembly()
        XCTAssertEqual(model.results.last?.assessment, .differsFromSample)
        XCTAssertTrue(model.weakAspects.isEmpty)
        model.next(); XCTAssertNil(model.proposedRating)
    }
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
    func testMalformedExtendedExerciseFallsBackToUnscoredSourcePractice() async throws {
        let original = try await loadRule("tai")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var exercises = try XCTUnwrap(object["exercises"] as? [[String: Any]])
        exercises[0]["acceptedOptionIDs"] = ["nonexistent-option"]
        object["exercises"] = exercises
        let rule = try JSONDecoder().decode(GrammarRule.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(rule.examples.count, original.examples.count)
        let practice = GrammarPracticeViewModel(rule: rule, seed: "bad-content")
        XCTAssertNil(practice.contentError); XCTAssertFalse(practice.isSelfAssessment)
        XCTAssertTrue(practice.exercises.allSatisfy { $0.kind == .restoreSentence && $0.isScored == false })
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
        XCTAssertEqual(model.count, 4)
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
    func testBundledAssemblyAcceptsEquivalentWordOrders() async throws {
        let rule = try await loadRule("te-hoshii")
        let exercise = try XCTUnwrap(rule.exercises?.first { $0.kind == .assembleSentence })
        XCTAssertTrue(exercise.accepts(order: ["0", "1", "2", "3", "4"]))
        XCTAssertTrue(exercise.accepts(order: ["1", "0", "2", "3", "4"]))
        XCTAssertFalse(exercise.accepts(order: ["0", "1", "5", "3", "4"]))
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
    func testFormInputAcceptsKanaAndKanjiAndRejectsWrongForm() async throws {
        let rule = try await loadRule("tai")
        let exercise = try XCTUnwrap(rule.exercises?.first { $0.id == "tai:form-eat" })
        XCTAssertTrue(GrammarAnswerValidator.accepts("食べたい", for: exercise))
        XCTAssertTrue(GrammarAnswerValidator.accepts(" たべたい\n", for: exercise))
        XCTAssertFalse(GrammarAnswerValidator.accepts("食べるたい", for: exercise))
        XCTAssertFalse(GrammarAnswerValidator.accepts("食べたいです", for: exercise))
        XCTAssertFalse(GrammarAnswerValidator.accepts("", for: exercise))
        let model = GrammarPracticeViewModel(rule: rule.withExercises([exercise] + (rule.exercises ?? []).filter { $0.kind != .formProduction }), seed: "input")
        XCTAssertEqual(model.currentExercise?.kind, .formProduction)
        model.textAnswer = "たべたい"; model.checkForm(); model.checkForm()
        XCTAssertEqual(model.results.count, 1); XCTAssertTrue(model.results[0].isCorrect)
        model.next(); XCTAssertEqual(model.textAnswer, "")
    }
    func testExplicitMetadataAndRepresentativeLessonsPreserveSourceLevels() async throws {
        let rules = try await GrammarDataLoader.shared.allRules()
        XCTAssertEqual(rules.filter { $0.practiceMetadata != nil }.count, 526)
        for rule in rules {
            let plan = try XCTUnwrap(rule.practiceMetadata)
            XCTAssertEqual(plan.categories.map(\.rawValue), rule.tags)
            XCTAssertEqual(plan.sourceExampleCount, rule.examples.count)
            XCTAssertEqual(Set(plan.availableKinds), Set((rule.exercises ?? []).map(\.kind)))
            XCTAssertFalse(plan.plannedKinds.isEmpty)
        }
        for id in ["tai", "te-hoshii", "you-ni-suru", "wake-de-wa-nai", "zu-ni-wa-okanai-nai-de-wa-okanai"] {
            let rule = try await loadRule(id)
            XCTAssertNotNil(rule.teaching); XCTAssertNotNil(rule.supplement)
            for review in [false, true] {
                let model = GrammarPracticeViewModel(rule: rule, seed: id, isReview: review)
                XCTAssertEqual(model.isLessonRead, review)
                while !model.isComplete {
                    answer(model, exercise: try XCTUnwrap(model.currentExercise), correct: true); model.next()
                }
                XCTAssertEqual(model.proposedRating, .good)
                XCTAssertLessThanOrEqual(model.count, 8)
            }
        }
        let you = try await loadRule("you-ni-suru"), wake = try await loadRule("wake-de-wa-nai")
        XCTAssertEqual(you.level, .n4); XCTAssertEqual(wake.level, .n3)
    }
    func testDifficultyWeightedRatingAndAssistanceAreDeterministic() {
        let exercises = [fixture(id: "a", difficulty: 3), fixture(id: "b", difficulty: 1), fixture(id: "c", difficulty: 1)]
        let results = [GrammarExerciseResult(exerciseID: "a", optionID: "no", isCorrect: false),
            .init(exerciseID: "b", optionID: "yes", isCorrect: true), .init(exerciseID: "c", optionID: "yes", isCorrect: true)]
        XCTAssertEqual(GrammarLessonRating.rating(results: results, exercises: exercises), .again)
        XCTAssertNil(GrammarLessonRating.rating(results: results + [results[0]], exercises: exercises))
        let helped = exercises.map { GrammarExerciseResult(exerciseID: $0.id, optionID: "yes", isCorrect: true, usedHint: true) }
        XCTAssertEqual(GrammarLessonRating.rating(results: helped, exercises: exercises), .hard)
    }
    func testEveryRequiredApplicationKindHasOfflineMaterialAcrossAllLevels() async throws {
        let all = try await GrammarDataLoader.shared.allRules()
        XCTAssertEqual(Set(all.filter { $0.teaching != nil }.map(\.level)), Set(GrammarLevel.allCases))
        let exercises = all.flatMap { $0.exercises ?? [] }
        for kind in [GrammarExerciseKind.fillBlank, .transformSentence, .assembleSentence, .chooseContext, .correctError, .distinguishMeaning, .understandSentence] {
            XCTAssertTrue(exercises.contains { $0.kind == kind && $0.eligibleForPractice })
        }
        for rule in all where rule.teaching == nil {
            XCTAssertNil(GrammarPracticeViewModel(rule: rule, seed: "offline").contentError)
        }
    }
    func testBasicSourcePracticeCoversEveryRuleWithoutFabricatedRatings() async throws {
        let all = try await GrammarDataLoader.shared.allRules()
        XCTAssertEqual(all.count, 526)
        XCTAssertEqual(all.filter { GrammarExerciseEngine.hasPractice($0) }.count, 526)
        XCTAssertEqual(all.filter { GrammarExerciseEngine.hasExtendedPractice($0) }.count, 14)
        XCTAssertEqual(all.flatMap { GrammarExerciseEngine.basicExercises(for: $0) }.count, 1526)
        for rule in all where rule.teaching == nil {
            let model = GrammarPracticeViewModel(rule: rule, seed: "basic")
            XCTAssertNil(model.contentError)
            XCTAssertFalse(model.exercises.isEmpty)
            XCTAssertEqual(Set(model.exercises.map(\.id)).count, model.count)
            while let exercise = model.currentExercise {
                XCTAssertEqual(exercise.kind, .restoreSentence)
                XCTAssertEqual(exercise.isScored, false)
                XCTAssertFalse(exercise.eligibleForPractice)
                XCTAssertEqual(exercise.provenance?.status, .structurallyChecked)
                XCTAssertNil(exercise.reviewer)
                XCTAssertTrue(rule.examples.contains { $0.ja == exercise.correctAnswer })
                XCTAssertFalse(GrammarAnswerValidator.accepts("別の表現です。", for: exercise))
                model.textAnswer = exercise.correctAnswer
                model.checkForm(); XCTAssertTrue(model.results.last?.isCorrect == true)
                model.next()
            }
            XCTAssertTrue(model.isComplete)
            XCTAssertNil(model.proposedRating)
            XCTAssertNil(model.beginSaving())
        }
    }
    func testSingleSourceExampleIsAvailableAndNeverRated() async throws {
        let original = try await loadRule("tai")
        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "teaching"); object.removeValue(forKey: "exercises")
        object["examples"] = (object["examples"] as? [[String: Any]])?.prefix(1).map { $0 }
        let rule = try JSONDecoder().decode(GrammarRule.self, from: JSONSerialization.data(withJSONObject: object))
        let model = GrammarPracticeViewModel(rule: rule, seed: "one")
        XCTAssertEqual(model.count, 1); XCTAssertNil(model.contentError)
        model.textAnswer = try XCTUnwrap(model.currentExercise).correctAnswer
        model.checkForm(); model.next()
        XCTAssertTrue(model.isComplete); XCTAssertNil(model.proposedRating)
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
        if exercise.kind == .formProduction {
            model.textAnswer = correct ? exercise.correctAnswer : (exercise.options.first { !exercise.accepts($0.id) }?.text ?? "неверный ответ")
            model.checkForm()
        } else if exercise.kind == .assembleSentence {
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
