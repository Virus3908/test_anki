import XCTest
@testable import kanji_test

@MainActor
final class GrammarStudyIntegrationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAllRatingsUseExistingSchedulerAndOneRecordPerRule() throws {
        for rating in ReviewRating.allCases {
            var progress = StudyProgressStore(records: [:])
            let key = ReviewItem(id: "te-hoshii", mode: .grammar).reviewKey
            _ = try progress.apply(rating, to: key, deckID: GrammarLevel.n4.deck.id, options: DeckOptions(), now: now)
            XCTAssertEqual(progress.records.count, 1)
            XCTAssertEqual(progress.reviewLog.count, 1)
            XCTAssertEqual(progress.reviewLog[0].cardID, "grammar:te-hoshii")
            XCTAssertEqual(progress.reviewLog[0].deckID, "grammar:n4")
            XCTAssertEqual(progress.record(for: key)?.schedulerVersion, "fsrs-6")
            XCTAssertEqual(progress.record(for: key)?.attempts, 1)
            XCTAssertEqual(progress.record(for: key)?.state, rating == .easy ? .review : .learning)
        }
    }

    func testAgainFromReviewProducesRelearningAndUndoRestoresExactRecord() throws {
        var progress = StudyProgressStore(records: [:])
        let key = "grammar:wa"
        _ = try progress.apply(.easy, to: key, deckID: "grammar:n5", options: DeckOptions(), now: now)
        let previous = try XCTUnwrap(progress.record(for: key))
        let log = try progress.apply(.again, to: key, deckID: "grammar:n5", options: DeckOptions(), now: previous.dueDate)
        XCTAssertEqual(progress.record(for: key)?.state, .relearning)
        XCTAssertEqual(progress.record(for: key)?.lapses, 1)
        progress.undo(logID: log, record: previous, key: key)
        XCTAssertEqual(progress.record(for: key)?.attempts, previous.attempts)
        XCTAssertEqual(progress.record(for: key)?.dueDate, previous.dueDate)
        XCTAssertEqual(progress.reviewLog.count, 1)
    }

    func testGrammarQueueCountsWaitingLearningAndDailyLimits() throws {
        let date = Calendar.current.startOfDay(for: now).addingTimeInterval(12 * 3600)
        var progress = StudyProgressStore(records: [:])
        _ = try progress.apply(.again, to: "grammar:wa", deckID: "grammar:n5", options: DeckOptions(), now: date)
        var options = DeckOptions(); options.dailyNewCardLimit = 1
        let plan = TrainingSessionEngine.plan(sourceIDs: ["wa", "ga-subject", "other"], mode: .grammar,
            deckID: "grammar:n5", progress: progress, options: options, now: date)
        XCTAssertEqual(plan.newCount, 0)
        XCTAssertEqual(plan.todayIDs, ["wa"])
        XCTAssertEqual(plan.learningCount, 1)
        XCTAssertEqual(plan.nextLearningDate, progress.record(for: "grammar:wa")?.dueDate)
        progress.advanceStudyDay()
        let next = TrainingSessionEngine.plan(sourceIDs: ["wa", "ga-subject", "other"], mode: .grammar,
            deckID: "grammar:n5", progress: progress, options: options, now: date)
        XCTAssertEqual(next.newCount, 1)
        XCTAssertTrue(next.todayIDs.contains("wa"))
    }

    func testGrammarResetAndPersistencePreserveOtherModesAndLegacyJSON() throws {
        var progress = try JSONDecoder().decode(StudyProgressStore.self, from: Data("{\"records\":{}}".utf8))
        let oldKeys = ["日", "word:猫-ねこ", "kana:あ", "anki:import:card:1"]
        for key in oldKeys {
            _ = try progress.apply(.good, to: key, deckID: "existing", options: DeckOptions(), now: now)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let originals = try encoder.encode(progress.records)
        _ = try progress.apply(.easy, to: "grammar:wa", deckID: "grammar:n5", options: DeckOptions(), now: now)
        progress = try JSONDecoder().decode(StudyProgressStore.self, from: encoder.encode(progress))
        XCTAssertNotNil(progress.record(for: "grammar:wa"))
        progress.resetProgress(for: ["grammar:wa"])
        XCTAssertEqual(try encoder.encode(progress.records), originals)
        XCTAssertEqual(progress.reviewLog.map(\.cardID), oldKeys)
        XCTAssertNil(progress.firstShownAt["grammar:wa"])
    }

    func testStatisticsReflectSRSStatesRatherThanClaimingKnowledgePercent() throws {
        let records = ["grammar:wa": StudyReviewRecord(attempts: 1, intervalDays: 0, dueDate: now,
            lastRating: .again, lastReviewedAt: now, state: .relearning, learningStep: 0, lapses: 1,
            stability: 1, difficulty: 5, schedulerVersion: "fsrs-6")]
        let rules = try JSONDecoder().decode([GrammarRule].self, from: Data("""
        [{"id":"wa","level":"N5","pattern":"〜は","meaning":"topic","formation":"Noun + は","examples":[],"tags":["particle"]},
         {"id":"ga","level":"N5","pattern":"〜が","meaning":"subject","formation":"Noun + が","examples":[],"tags":["particle"]}]
        """.utf8))
        let stats = GrammarStatistics(rules: rules, progress: StudyProgressStore(records: records), now: now)
        XCTAssertEqual(stats.total, 2); XCTAssertEqual(stats.new, 1)
        XCTAssertEqual(stats.relearning, 1); XCTAssertEqual(stats.due, 1); XCTAssertEqual(stats.review, 0)
    }

    func testRuleStatusUsesExistingMasteryAndKeepsLearningDistinct() async throws {
        let rules = try await GrammarDataLoader.shared.rules(.n5)
        let rule = try XCTUnwrap(rules.first)
        var record = StudyReviewRecord(attempts: 3, intervalDays: 10, dueDate: now,
            lastRating: .good, lastReviewedAt: Date(), state: .review, learningStep: 0,
            lapses: 0, stability: 100, difficulty: 1, schedulerVersion: "fsrs-6")
        var progress = StudyProgressStore(records: [rule.reviewKey: record])
        XCTAssertEqual(GrammarStatistics.status(rule, progress: progress), "Изучено хорошо")
        record.lastReviewedAt = Date(timeIntervalSince1970: 0); record.stability = 0.1
        progress = StudyProgressStore(records: [rule.reviewKey: record])
        XCTAssertEqual(GrammarStatistics.status(rule, progress: progress), "На повторении")
        record.state = .learning
        progress = StudyProgressStore(records: [rule.reviewKey: record])
        XCTAssertEqual(GrammarStatistics.status(rule, progress: progress), "В процессе изучения")
        record.state = .relearning
        progress = StudyProgressStore(records: [rule.reviewKey: record])
        XCTAssertEqual(GrammarStatistics.status(rule, progress: progress), "Повторное обучение")
        progress.exclude(rule.reviewKey)
        XCTAssertEqual(GrammarStatistics.status(rule, progress: progress), "Исключено")
    }

    func testSharedSessionPersistsUndoAndAdditionalCardsWithIndependentDecks() async throws {
        let repository = GrammarMemoryReviews()
        let suite = "GrammarTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let catalog = StudyCardCatalog()
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        let rules = Array(try await GrammarDataLoader.shared.rules(.n5).prefix(3))
        try await session.loadProgress()
        settings.updateOptions(for: "grammar:n5") { $0.dailyNewCardLimit = 0 }
        let ids = catalog.register(rules)
        let empty = await session.start(deck: GrammarLevel.n5.deck, sourceIDs: ids)
        XCTAssertTrue(empty); XCTAssertTrue(session.didCompleteToday)
        session.addNewCardsToToday(2, for: "grammar:n5")
        let started = await session.start(deck: GrammarLevel.n5.deck, sourceIDs: ids)
        XCTAssertTrue(started); XCTAssertEqual(session.sessionTotalCards, 2)
        XCTAssertEqual(session.currentGrammarRule?.id, rules[0].id)
        await session.submitReview(.good, expectedKey: rules[0].reviewKey)
        XCTAssertEqual(session.reviewStore.reviewLog.count, 1)
        XCTAssertEqual(session.currentGrammarRule?.id, rules[1].id)
        XCTAssertNotNil(session.reviewStore.record(for: rules[0].reviewKey))
        let saved = try await repository.load()
        XCTAssertEqual(saved.reviewLog.count, 1)
        await session.moveToPreviousCard()
        XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
        XCTAssertNil(session.reviewStore.record(for: rules[0].reviewKey))
        XCTAssertEqual(session.currentGrammarRule?.id, rules[0].id)
        XCTAssertEqual(settings.options(for: "grammar:n5").dailyNewCardLimit, 0)
        XCTAssertEqual(settings.options(for: "grammar:n4").dailyNewCardLimit, 10)
        XCTAssertNil(errors.message)
        session.finish()
        let restarted = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        try await restarted.loadProgress()
        XCTAssertEqual(restarted.reviewStore.firstShownAt.keys.sorted(), session.reviewStore.firstShownAt.keys.sorted())
    }

    func testSavedResultIsHeldOnceUntilContinueAndUndoRestoresLesson() async throws {
        let repository = GrammarMemoryReviews()
        let suite = "GrammarPending-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let catalog = StudyCardCatalog()
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        let rules = Array(try await GrammarDataLoader.shared.rules(.n5).prefix(2))
        try await session.loadProgress()
        let started = await session.start(deck: GrammarLevel.n5.deck, sourceIDs: catalog.register(rules))
        XCTAssertTrue(started)
        let revision = session.scrollToTopToken
        await session.submitReview(.good, expectedKey: rules[0].reviewKey, holdGrammarResult: true)
        await session.submitReview(.good, expectedKey: rules[0].reviewKey, holdGrammarResult: true)
        XCTAssertTrue(session.isGrammarResultPending)
        XCTAssertEqual(session.scrollToTopToken, revision)
        XCTAssertEqual(session.currentGrammarRule?.id, rules[0].id)
        XCTAssertEqual(session.reviewStore.reviewLog.count, 1)
        let stored = try await repository.load()
        XCTAssertEqual(stored.reviewLog.count, 1)
        await session.refreshForNewDay()
        XCTAssertTrue(session.isGrammarResultPending)
        await session.continueGrammarAfterResult()
        await session.continueGrammarAfterResult()
        XCTAssertFalse(session.isGrammarResultPending)
        XCTAssertEqual(session.currentGrammarRule?.id, rules[1].id)
        XCTAssertEqual(session.reviewStore.reviewLog.count, 1)
        await session.moveToPreviousCard()
        XCTAssertEqual(session.currentGrammarRule?.id, rules[0].id)
        XCTAssertNil(session.reviewStore.record(for: rules[0].reviewKey))
        XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
    }

    func testUnfinishedLessonResumesInMemoryAndTheoryDoesNotDiscardAnswers() async throws {
        let repository = GrammarMemoryReviews()
        let suite = "GrammarResume-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let catalog = StudyCardCatalog()
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        let loaded = try await GrammarDataLoader.shared.rule("tai")
        let rule = try XCTUnwrap(loaded)
        let ids = catalog.register([rule])
        try await session.loadProgress()
        let started = await session.start(deck: GrammarLevel.n5.deck, sourceIDs: ids)
        XCTAssertTrue(started)
        let model = session.practice(for: rule)
        model.isLessonRead = true
        model.choose(try XCTUnwrap(model.currentExercise?.acceptedOptionIDs.first))
        model.useHint()
        XCTAssertEqual(model.results.count, 1)
        session.finish()
        XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
        let stored = try await repository.load()
        XCTAssertTrue(stored.reviewLog.isEmpty)
        let resumed = await session.start(deck: GrammarLevel.n5.deck, sourceIDs: ids)
        XCTAssertTrue(resumed)
        let same = session.practice(for: rule)
        XCTAssertTrue(same === model); XCTAssertEqual(same.results.count, 1)
        XCTAssertTrue(same.isLessonRead); XCTAssertTrue(same.isAnswerVisible)
        XCTAssertNil(same.proposedRating)
        let otherLoaded = try await GrammarDataLoader.shared.rule("wa")
        let other = try XCTUnwrap(otherLoaded)
        XCTAssertFalse(session.practice(for: other) === model)
    }

    func testCancelledSearchCannotPublishPreviousResults() async throws {
        let model = GrammarLibraryViewModel()
        await model.load()
        XCTAssertNil(model.error)
        let previous = Task { await model.search("", level: .n5, category: nil) }
        await Task.yield()
        await model.search("tsumori", level: .n4, category: nil)
        let expected = model.results.map(\.id)
        XCTAssertTrue(expected.contains("tsumori"))
        await previous.value
        XCTAssertEqual(model.results.map(\.id), expected)
        model.invalidateSearch()
        XCTAssertTrue(model.results.isEmpty)
    }
    func testFiveRepresentativeLessonsCreateOneFSRSReviewAndRestoreWithUndo() async throws {
        for id in ["tai", "te-hoshii", "you-ni-suru", "wake-de-wa-nai", "zu-ni-wa-okanai-nai-de-wa-okanai"] {
            let repository = GrammarMemoryReviews()
            let suite = "GrammarComplete-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let errors = StorageStatus()
            let settings = StudyPreferences(defaults: defaults, errors: errors)
            let catalog = StudyCardCatalog()
            let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
            let loaded = try await GrammarDataLoader.shared.rule(id)
            let rule = try XCTUnwrap(loaded)
            try await session.loadProgress()
            let started = await session.start(deck: rule.level.deck, sourceIDs: catalog.register([rule]))
            XCTAssertTrue(started)
            let model = session.practice(for: rule)
            model.isLessonRead = true
            while !model.isComplete {
                let exercise = try XCTUnwrap(model.currentExercise)
                if exercise.kind == .formProduction { model.textAnswer = exercise.correctAnswer; model.checkForm() }
                else if exercise.kind == .assembleSentence {
                    for element in try XCTUnwrap(exercise.acceptedOrders?.first) { model.toggleElement(element) }
                    model.checkAssembly()
                } else { model.choose(try XCTUnwrap(exercise.acceptedOptionIDs.first)) }
                XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
                model.next()
            }
            let rating = try XCTUnwrap(model.beginSaving())
            await session.submitReview(rating, expectedKey: rule.reviewKey, holdGrammarResult: true)
            model.finishSaving(success: session.isGrammarResultPending)
            XCTAssertNil(model.beginSaving())
            XCTAssertEqual(session.reviewStore.reviewLog.count, 1)
            XCTAssertEqual(session.reviewStore.record(for: rule.reviewKey)?.schedulerVersion, "fsrs-6")
            let restarted = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
            try await restarted.loadProgress()
            XCTAssertEqual(restarted.reviewStore.reviewLog.count, 1)
            let resumed = await restarted.start(deck: rule.level.deck, sourceIDs: catalog.register([rule]))
            XCTAssertTrue(resumed)
            XCTAssertTrue(restarted.practice(for: rule).isLessonRead)
            await session.moveToPreviousCard()
            XCTAssertNil(session.reviewStore.record(for: rule.reviewKey))
            XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
        }
    }
}

private actor GrammarMemoryReviews: ReviewPersisting {
    private var stored = StudyProgressStore(records: [:])
    func load() -> StudyProgressStore { stored }
    func save(_ store: StudyProgressStore) { stored = store }
    func hasRecoverableBackup() -> Bool { false }
    func restoreBackup() -> StudyProgressStore { stored }
}
