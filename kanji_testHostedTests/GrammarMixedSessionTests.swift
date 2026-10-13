import XCTest
@testable import kanji_test

@MainActor
final class GrammarMixedSessionTests: XCTestCase {
    private func rules() async throws -> [GrammarRule] {
        try await GrammarDataLoader.shared.allRules().filter { $0.teaching != nil }
    }
    private func answer(_ model: GrammarPracticeViewModel, correct: Bool = true) throws {
        let e = try XCTUnwrap(model.currentExercise)
        if e.kind == .formProduction { model.textAnswer = correct ? e.correctAnswer : try XCTUnwrap(e.options.first { !e.accepts($0.id) }?.text); model.checkForm() }
        else if e.kind == .assembleSentence {
            let order = correct ? try XCTUnwrap(e.acceptedOrders?.first) : [e.options.last!.id]
            for id in order { model.toggleElement(id) }
            model.checkAssembly()
        } else { model.choose(try XCTUnwrap(e.options.first { e.accepts($0.id) == correct }?.id)) }
    }
    private func mixed(_ rules: [GrammarRule], progress: StudyProgressStore = .init(records: [:]), seed: String = "fixed") -> GrammarMixedSessionViewModel {
        let levels = Set(rules.map(\.level))
        let options = Dictionary(uniqueKeysWithValues: levels.map { ($0, DeckOptions()) })
        return GrammarMixedSessionViewModel(candidates: GrammarSessionPlanner.candidates(rules: rules, levels: levels,
            scope: .mixed, progress: progress, options: options), levels: levels, scope: .mixed, progress: progress, seed: seed)
    }
    func testBasicRulesMixAndFinishWithoutUnsavedFSRSResults() async throws {
        let source = try await GrammarDataLoader.shared.rules(.n5).filter { $0.teaching == nil }
        let model = mixed(source)
        XCTAssertGreaterThan(model.practices.count, 1)
        while !model.isComplete {
            let practice = try XCTUnwrap(model.current)
            practice.isLessonRead = true
            let exercise = try XCTUnwrap(practice.currentExercise)
            practice.textAnswer = exercise.correctAnswer
            practice.checkForm(); model.advance()
        }
        XCTAssertFalse(model.hasUnsavedResults)
        XCTAssertEqual(model.savedRules, 0)
        XCTAssertEqual(model.newRules, 0)
        XCTAssertEqual(model.basicCompletedRules, model.practices.count)
        XCTAssertTrue(model.practices.allSatisfy { $0.proposedRating == nil && !$0.isSaved })
        XCTAssertEqual(Set(model.completedExerciseIDs).count, model.completedExerciseIDs.count)
        XCTAssertGreaterThan(Set(model.history).count, 1)
    }
    func testMultipleRulesAlternateWithNoDuplicateQuestionAndBoundedAttempts() async throws {
        let model = mixed(try await rules().filter { $0.level == .n5 })
        XCTAssertGreaterThan(model.practices.count, 1)
        while !model.isComplete {
            let practice = try XCTUnwrap(model.current)
            if !practice.isLessonRead { practice.isLessonRead = true }
            try answer(practice); model.advance()
            XCTAssertLessThanOrEqual(model.history.count, GrammarSessionPlanner.maximumRules * GrammarPracticeViewModel.maximumCount)
        }
        XCTAssertEqual(Set(model.completedExerciseIDs).count, model.completedExerciseIDs.count)
        for pair in zip(model.history, model.history.dropFirst()) {
            // The tail can legitimately contain one final active rule.
            if pair.0 == pair.1 { XCTAssertEqual(model.history.last, pair.0) }
        }
        XCTAssertEqual(model.answered, model.correct)
    }
    func testFixedSeedProducesSameExerciseAndRuleSequence() async throws {
        let source = try await rules()
        let a = mixed(source), b = mixed(source)
        while !a.isComplete {
            let pa = try XCTUnwrap(a.current), pb = try XCTUnwrap(b.current)
            XCTAssertEqual(pa.rule.id, pb.rule.id); XCTAssertEqual(pa.currentExercise?.id, pb.currentExercise?.id)
            pa.isLessonRead = true; pb.isLessonRead = true
            try answer(pa); try answer(pb); a.advance(); b.advance()
        }
        XCTAssertEqual(a.history, b.history)
    }
    func testContextPrerequisitesAreTaughtBeforeTheyEnterMixedQuestions() async throws {
        let source = try await rules()
        let onlyN4 = mixed(source.filter { $0.level == .n4 })
        XCTAssertFalse(onlyN4.practices.flatMap(\.exercises).contains { ($0.requiredRuleIDs ?? []).contains("tai") })
        let all = mixed(source)
        while !all.isComplete {
            let current = try XCTUnwrap(all.current)
            for id in current.currentExercise?.requiredRuleIDs ?? [] {
                let prerequisite = try XCTUnwrap(all.practices.first { $0.rule.id == id })
                XCTAssertTrue(prerequisite.isLessonRead)
                XCTAssertGreaterThan(prerequisite.results.count, 0)
            }
            current.isLessonRead = true; try answer(current); all.advance()
        }
    }
    func testNoUnknownRulesInStudiedScopeAndNoCrossLevelRules() async throws {
        let source = try await rules()
        let now = Date()
        var progress = StudyProgressStore(records: [:])
        _ = try progress.apply(.again, to: "grammar:tai", deckID: "grammar:n5", options: DeckOptions(), now: now.addingTimeInterval(-3600))
        let selected = GrammarSessionPlanner.candidates(rules: source, levels: [.n5], scope: .studied,
            progress: progress, options: [.n5: DeckOptions()], now: now)
        XCTAssertEqual(selected.map { $0.rule.id }, ["tai"])
        XCTAssertTrue(selected.allSatisfy { $0.rule.level == .n5 })
    }
    func testSharedQueueLearningReviewsAndDailyNewLimit() async throws {
        let source = try await rules().filter { $0.level == .n5 }
        let now = Date()
        var progress = StudyProgressStore(records: [:])
        // Introduce the learning card on the preceding day. A same-day introduction
        // already consumes the single new-card allowance this fixture is testing.
        _ = try progress.apply(.again, to: "grammar:tai", deckID: "grammar:n5", options: DeckOptions(), now: now.addingTimeInterval(-86400))
        _ = try progress.apply(.easy, to: "grammar:wa", deckID: "grammar:n5", options: DeckOptions(), now: now.addingTimeInterval(-30 * 86400))
        var options = DeckOptions(); options.dailyNewCardLimit = 0
        let candidates = GrammarSessionPlanner.candidates(rules: source, levels: [.n5], scope: .mixed,
            progress: progress, options: [.n5: options], now: now)
        XCTAssertEqual(candidates.first?.rule.id, "tai")
        XCTAssertTrue(candidates.contains { $0.rule.id == "wa" })
        XCTAssertFalse(candidates.contains { $0.rule.id == "te-mo-ii" })
        options.dailyNewCardLimit = 1
        let granted = GrammarSessionPlanner.candidates(rules: source, levels: [.n5], scope: .mixed,
            progress: progress, options: [.n5: options], now: now)
        XCTAssertEqual(granted.filter { progress.record(for: $0.rule.reviewKey) == nil }.count, 1)
    }
    func testNewRuleHasTheoryAndOneWarmupBeforeReturningInMixedPractice() async throws {
        let model = mixed(try await rules().filter { $0.level == .n5 })
        let first = try XCTUnwrap(model.current)
        XCTAssertFalse(first.isLessonRead)
        first.next(); XCTAssertTrue(first.results.isEmpty)
        first.isLessonRead = true; try answer(first); model.advance()
        let next = try XCTUnwrap(model.current)
        XCTAssertNotEqual(next.rule.id, first.rule.id)
        XCTAssertFalse(next.isLessonRead)
        XCTAssertEqual(first.results.count, 1)
    }
    func testErrorReturnsAfterOtherQuestionsWithDifferentContext() async throws {
        let model = mixed(try await rules().filter { $0.level == .n5 })
        let first = try XCTUnwrap(model.current)
        first.isLessonRead = true
        let question = try XCTUnwrap(first.currentExercise)
        try answer(first, correct: false); model.advance()
        XCTAssertNotEqual(model.currentRuleID, first.rule.id)
        var otherAnswers = 0
        while model.currentRuleID != first.rule.id, !model.isComplete {
            let practice = try XCTUnwrap(model.current); practice.isLessonRead = true
            try answer(practice); model.advance(); otherAnswers += 1
        }
        XCTAssertGreaterThanOrEqual(otherAnswers, 2)
        XCTAssertNotEqual(first.currentExercise?.id, question.id)
        XCTAssertEqual(first.currentExercise?.aspect, question.aspect)
    }
    func testSingleRuleAndEmptyPlan() async throws {
        let source = try await rules()
        let model = mixed(Array(source.prefix(1)))
        while !model.isComplete {
            let practice = try XCTUnwrap(model.current); practice.isLessonRead = true
            try answer(practice); model.advance()
        }
        XCTAssertEqual(Set(model.history).count, 1)
        XCTAssertNil(GrammarSessionPlanner.nextRule([], previousID: nil, step: 0, seed: "empty"))
        XCTAssertTrue(GrammarSessionPlanner.candidates(rules: [], levels: [.n5], scope: .mixed,
            progress: .init(records: [:]), options: [:]).isEmpty)
    }
    func testCompletedRulesSaveOnceUndoAndRestartPreserveOtherResults() async throws {
        let source = try await rules().filter { $0.level == .n5 }
        let repository = MixedMemoryReviews()
        let suite = "Mixed-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus(), catalog = StudyCardCatalog()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        try await session.loadProgress()
        let started = await session.startMixedGrammar(rules: source, levels: [.n5], scope: .mixed)
        XCTAssertTrue(started)
        let model = try XCTUnwrap(session.grammarMixed)
        while !model.isComplete {
            let practice = try XCTUnwrap(model.current)
            if !practice.isLessonRead { await session.introduceMixedGrammarRule() }
            try answer(practice)
            await session.advanceMixedGrammar()
        }
        XCTAssertEqual(session.reviewStore.reviewLog.count, model.practices.count)
        await session.saveMixedGrammarResults()
        XCTAssertEqual(session.reviewStore.reviewLog.count, model.practices.count)
        let before = session.reviewStore.records
        let last = try XCTUnwrap(session.state.undoHistory.last)
        await session.moveToPreviousCard()
        XCTAssertFalse(model.isComplete)
        XCTAssertNil(session.reviewStore.record(for: last.reviewKey))
        for (key, record) in before where key != last.reviewKey {
            XCTAssertEqual(session.reviewStore.record(for: key)?.attempts, record.attempts)
            XCTAssertEqual(session.reviewStore.record(for: key)?.dueDate, record.dueDate)
        }
        let restarted = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        try await restarted.loadProgress()
        XCTAssertEqual(restarted.reviewStore.reviewLog.count, model.practices.count - 1)
        XCTAssertNil(errors.message)
    }
    func testPartialExitDoesNotScoreIncompleteRulesAndResumesAnswers() async throws {
        let source = try await rules().filter { $0.level == .n5 }
        let repository = MixedMemoryReviews()
        let suite = "MixedPartial-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let session = TrainingSessionViewModel(repository: repository, catalog: StudyCardCatalog(),
            settings: StudyPreferences(defaults: defaults, errors: errors), errors: errors)
        try await session.loadProgress()
        let started = await session.startMixedGrammar(rules: source, levels: [.n5], scope: .mixed)
        XCTAssertTrue(started)
        let model = try XCTUnwrap(session.grammarMixed)
        await session.introduceMixedGrammarRule()
        try answer(try XCTUnwrap(model.current)); await session.advanceMixedGrammar()
        session.finish()
        XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
        let resumed = await session.startMixedGrammar(rules: source, levels: [.n5], scope: .mixed)
        XCTAssertTrue(resumed); XCTAssertTrue(session.grammarMixed === model)
        XCTAssertEqual(model.answered, 1)
    }
    func testPerDeckLimitsIncludeAdditionalGrantsWithoutChangingOptions() async throws {
        let source = try await rules()
        let suite = "MixedLimits-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = StudyPreferences(defaults: defaults, errors: StorageStatus())
        for level in [GrammarLevel.n5, .n4] { preferences.updateOptions(for: level.deck.id) { $0.dailyNewCardLimit = 0 } }
        let progress = StudyProgressStore(records: [:])
        preferences.addAdditionalCards(1, for: GrammarLevel.n4.deck.id, studyDay: progress.studyDate())
        let options = Dictionary(uniqueKeysWithValues: [GrammarLevel.n5, .n4].map {
            ($0, preferences.effectiveOptions(for: $0.deck.id, studyDay: progress.studyDate()))
        })
        let candidates = GrammarSessionPlanner.candidates(rules: source, levels: [.n5, .n4], scope: .mixed,
            progress: progress, options: options)
        XCTAssertEqual(candidates.count, 1); XCTAssertEqual(candidates.first?.rule.level, .n4)
        XCTAssertEqual(preferences.options(for: GrammarLevel.n4.deck.id).dailyNewCardLimit, 0)
    }
}

private actor MixedMemoryReviews: ReviewPersisting {
    private var progress = StudyProgressStore(records: [:])
    func load() -> StudyProgressStore { progress }
    func save(_ value: StudyProgressStore) { progress = value }
    func hasRecoverableBackup() -> Bool { false }
    func restoreBackup() -> StudyProgressStore { progress }
}
