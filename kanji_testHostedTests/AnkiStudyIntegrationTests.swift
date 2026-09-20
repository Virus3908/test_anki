import XCTest
@testable import AnkiImport
@testable import kanji_test

@MainActor
final class AnkiStudyIntegrationTests: XCTestCase {
    func testSchedulingMigrationKeepsNewCardNew() {
        var progress = StudyProgressStore(records: [:])
        let collection = migrationCollection(type: 0, queue: 0, due: 1, interval: 0, reps: 0, history: [])
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
            optionsByDeck: [40: DeckOptions()], progress: &progress), 0)
        XCTAssertNil(progress.record(for: migrationKey))
    }

    func testFutureAndOverdueReviewScheduling() {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let creation = today.addingTimeInterval(-100 * 86_400)
        for (dueDay, expectedDue) in [(101, false), (99, true)] {
            var progress = StudyProgressStore(records: [:])
            let collection = migrationCollection(type: 2, queue: 2, due: Int64(dueDay), interval: 30,
                reps: 5, history: ratingHistory(), creation: Int64(creation.timeIntervalSince1970))
            XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
                optionsByDeck: [40: DeckOptions()], progress: &progress), 1)
            let record = progress.record(for: migrationKey)!
            XCTAssertEqual(record.state, .review)
            XCTAssertEqual(progress.isDue(record, now: now), expectedDue)
            XCTAssertGreaterThan(record.stability, 0)
        }
    }

    func testLearningAndRelearningRemainWaitingUntilTimestamp() {
        let now = Date()
        for (type, expected) in [(1, StudyReviewState.learning), (3, StudyReviewState.relearning)] {
            var progress = StudyProgressStore(records: [:])
            let collection = migrationCollection(type: type, queue: 1,
                due: Int64(now.addingTimeInterval(600).timeIntervalSince1970), interval: 0,
                reps: 2, lapses: type == 3 ? 1 : 0, left: 1001, history: ratingHistory())
            _ = AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
                optionsByDeck: [40: DeckOptions()], progress: &progress)
            let record = progress.record(for: migrationKey)!
            XCTAssertEqual(record.state, expected)
            XCTAssertFalse(progress.isDue(record, now: now))
            let plan = TrainingSessionEngine.plan(sourceIDs: ["fixture:card:30"], mode: .anki,
                deckID: migrationDeckID, progress: progress, options: DeckOptions(), now: now)
            XCTAssertEqual(plan.todayIDs, ["fixture:card:30"])
            XCTAssertEqual(plan.nextLearningDate, record.dueDate)
        }
    }

    func testRatingsOrderIdempotenceAndNewerAppProgressWins() throws {
        var progress = StudyProgressStore(records: [:])
        let collection = migrationCollection(type: 2, queue: 2, due: 0, interval: 10,
            reps: 5, history: ratingHistory(), creation: Int64(Date().timeIntervalSince1970))
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
            optionsByDeck: [40: DeckOptions()], progress: &progress), 1)
        XCTAssertEqual(progress.reviewLog.map(\.grade), [1, 3, 3, 2, 3])
        let logIDs = progress.reviewLog.map(\.id)
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
            optionsByDeck: [40: DeckOptions()], progress: &progress), 0)
        XCTAssertEqual(progress.reviewLog.map(\.id), logIDs)
        let appReviewDate = Date().addingTimeInterval(3600)
        _ = try progress.apply(.easy, to: migrationKey, deckID: migrationDeckID,
            options: DeckOptions(), now: appReviewDate)
        let appRecord = progress.record(for: migrationKey)
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection, importID: "fixture",
            optionsByDeck: [40: DeckOptions()], progress: &progress), 0)
        XCTAssertEqual(progress.record(for: migrationKey)?.lastReviewedAt, appRecord?.lastReviewedAt)
        XCTAssertEqual(progress.reviewLog.count, 6)
    }
    func testImportedPackageBecomesTwoDecksAndExcludesEmptyDefault() throws {
        let collection = try fixture()
        let model = AnkiLibraryViewModel()
        model.imports = [AnkiImportSummary(id: "package", directory: UUID().uuidString, filename: "two.apkg",
            importedAt: Date(), decks: collection.decks, cardCount: 3, noteCount: 1, mediaCount: 0, warnings: [],
            deckCardCounts: ["10": 2, "20": 1])]
        XCTAssertEqual(model.decks.count, 2)
        XCTAssertEqual(model.decks.map(\.title), ["First", "Second"])
        XCTAssertEqual(model.decks.map(\.cardCount), [2, 1])
        XCTAssertEqual(Set(model.decks.map(\.id)).count, 2)
        XCTAssertTrue(model.decks.allSatisfy { $0.studyDeck.mode == .anki })
        let navigation = StudyNavigation()
        navigation.open(.ankiDeck(model.decks[1]))
        navigation.beginTraining(.anki)
        navigation.finishTraining()
        XCTAssertEqual(navigation.route.deck?.id, model.decks[1].id)
    }

    func testReviewKeysAreStableAndDoNotCollideWithOtherImportsOrBuiltInCards() throws {
        let card = try cards().first!
        XCTAssertEqual(card.reviewKey, ReviewItem(id: card.id, mode: .anki).reviewKey)
        XCTAssertNotEqual(card.reviewKey, ReviewItem(id: card.id, mode: .kanji).reviewKey)
        let other = AnkiStudyCard(importID: "other", card: card.card, note: card.note, noteType: card.noteType,
                                  deckName: card.deckName, mediaDirectory: card.mediaDirectory)
        XCTAssertNotEqual(card.reviewKey, other.reviewKey)
    }

    func testSharedSRSReviewPersistenceUndoAndDeckLimits() async throws {
        let repository = MemoryReviews()
        let catalog = StudyCardCatalog()
        let errors = StorageStatus()
        let suite = "AnkiIntegration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let cards = try cards()
        let deck = AnkiDeckReference(importID: "package", sourceDeckID: 10, title: "First", cardCount: 2)
        settings.updateOptions(for: deck.id) { $0.dailyNewCardLimit = 2 }
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        try await session.loadProgress()
        let started = await session.start(deck: deck.studyDeck, sourceIDs: catalog.register(cards))
        XCTAssertTrue(started)
        XCTAssertEqual(session.currentAnkiCard?.id, cards[0].id)
        XCTAssertFalse(session.intervalLabel(for: .good).isEmpty)
        await session.submitReview(.good, expectedKey: cards[0].reviewKey)
        XCTAssertNotNil(session.reviewStore.record(for: cards[0].reviewKey))
        XCTAssertEqual(session.reviewStore.reviewLog.last?.deckID, deck.id)
        XCTAssertEqual(session.currentAnkiCard?.id, cards[1].id)
        XCTAssertTrue(session.canGoBack)
        let saved = try await repository.load()
        XCTAssertNotNil(saved.record(for: cards[0].reviewKey))
        await session.moveToPreviousCard()
        XCTAssertNil(session.reviewStore.record(for: cards[0].reviewKey))
        XCTAssertTrue(session.reviewStore.reviewLog.isEmpty)
        XCTAssertEqual(session.currentAnkiCard?.id, cards[0].id)
        XCTAssertNil(errors.message)
        XCTAssertEqual(settings.options(for: deck.id).dailyNewCardLimit, 2)
        XCTAssertEqual(settings.options(for: "another-deck").dailyNewCardLimit, 10)
    }

    func testCompletedDayAdditionalCardsAndPracticeDoNotBypassSharedRules() async throws {
        let repository = MemoryReviews()
        let catalog = StudyCardCatalog()
        let errors = StorageStatus()
        let suite = "AnkiIntegration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let cards = try cards()
        let deck = AnkiDeckReference(importID: "package", sourceDeckID: 10, title: "First", cardCount: 2)
        settings.updateOptions(for: deck.id) { $0.dailyNewCardLimit = 0 }
        let session = TrainingSessionViewModel(repository: repository, catalog: catalog, settings: settings, errors: errors)
        try await session.loadProgress()
        let ids = catalog.register(cards)
        _ = await session.start(deck: deck.studyDeck, sourceIDs: ids)
        XCTAssertTrue(session.didCompleteToday)
        XCTAssertFalse(session.isActive)
        session.addNewCardsToToday(1, for: deck.id)
        _ = await session.start(deck: deck.studyDeck, sourceIDs: ids)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.sessionTotalCards, 1)
        session.finish()
        let beforePractice = try await repository.load()
        _ = await session.start(deck: deck.studyDeck, sourceIDs: ids, guided: true)
        await session.submitReview(.easy, expectedKey: cards[0].reviewKey)
        let afterPractice = try await repository.load()
        XCTAssertEqual(beforePractice.reviewLog.count, afterPractice.reviewLog.count)
        XCTAssertNil(afterPractice.record(for: cards[0].reviewKey))
    }

    func testSchedulingMigrationFailureDoesNotBlockLibrary() async {
        let repository = MemoryAnkiLibrary(summaries: [migrationSummary()],
            collectionError: AnkiImportError.invalid("коллекция повреждена"))
        let model = AnkiLibraryViewModel(repository: repository)
        model.bootstrapScheduling = { _, _ in 0 }
        await model.load()
        XCTAssertTrue(model.isLoaded)
        XCTAssertFalse(model.decks.isEmpty)
        XCTAssertTrue(model.message?.contains("Не удалось перенести расписание") == true)
        let marked = await repository.markedVersions
        XCTAssertTrue(marked.isEmpty)
    }

    func testBootstrapSkippedBeforeProgressIsNotMarkedAndRetriedAfter() async throws {
        let suite = "AnkiMigration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let session = TrainingSessionViewModel(repository: MemoryReviews(), catalog: StudyCardCatalog(),
            settings: settings, errors: errors)
        let collection = migrationCollection(type: 2, queue: 2, due: 0, interval: 10,
            reps: 5, history: ratingHistory())
        let repository = MemoryAnkiLibrary(summaries: [migrationSummary()], collections: ["fixture": collection])
        let model = AnkiLibraryViewModel(repository: repository)
        model.bootstrapScheduling = { collection, importID in
            try await session.bootstrapAnkiHistory(collection, importID: importID)
        }
        await model.load()
        XCTAssertTrue(model.isLoaded)
        XCTAssertFalse(model.decks.isEmpty)
        XCTAssertNil(model.message)
        let markedEarly = await repository.markedVersions
        XCTAssertTrue(markedEarly.isEmpty)
        XCTAssertNil(session.reviewStore.record(for: migrationKey))
        try await session.loadProgress()
        await model.load()
        let markedLate = await repository.markedVersions
        XCTAssertEqual(markedLate["fixture"], AnkiSchedulingMigrator.version)
        XCTAssertNotNil(session.reviewStore.record(for: migrationKey))
    }

    func testBootstrapAnkiHistoryWaitsForProgressAndMigratesAfterwards() async throws {
        let suite = "AnkiMigration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        let repository = MemoryReviews()
        let session = TrainingSessionViewModel(repository: repository, catalog: StudyCardCatalog(),
            settings: settings, errors: errors)
        let collection = migrationCollection(type: 2, queue: 2, due: 0, interval: 10,
            reps: 5, history: ratingHistory())
        let skipped = try await session.bootstrapAnkiHistory(collection, importID: "fixture")
        XCTAssertNil(skipped)
        let before = try await repository.load()
        XCTAssertNil(before.record(for: migrationKey))
        XCTAssertTrue(before.reviewLog.isEmpty)
        try await session.loadProgress()
        let migrated = try await session.bootstrapAnkiHistory(collection, importID: "fixture")
        XCTAssertEqual(migrated, 1)
        let after = try await repository.load()
        XCTAssertNotNil(after.record(for: migrationKey))
    }

    private func migrationSummary() -> AnkiImportSummary {
        AnkiImportSummary(id: "fixture", directory: UUID().uuidString, filename: "sched.apkg",
            importedAt: Date(), decks: [.init(id: 40, name: "Deck")], cardCount: 1, noteCount: 1,
            mediaCount: 0, warnings: [], deckCardCounts: ["40": 1])
    }

    private func cards() throws -> [AnkiStudyCard] {
        let value = try fixture()
        return value.cards.filter { $0.deckID == 10 }.map {
            AnkiStudyCard(importID: "package", card: $0, note: value.notes[0], noteType: value.noteTypes[0],
                          deckName: "First", mediaDirectory: FileManager.default.temporaryDirectory)
        }
    }

    private func fixture() throws -> AnkiCollection {
        let json = #"{"decks":[{"id":1,"name":"Default"},{"id":10,"name":"First"},{"id":20,"name":"Second"}],"noteTypes":[{"id":5,"name":"Basic","isCloze":false,"fields":["Front","Back"],"templates":[{"ordinal":0,"name":"Forward","question":"{{Front}}","answer":"{{Back}}"},{"ordinal":1,"name":"Reverse","question":"{{Back}}","answer":"{{Front}}"}],"css":""}],"notes":[{"id":6,"guid":"guid","noteTypeID":5,"fields":["猫","cat"],"tags":[]}],"cards":[{"id":7,"noteID":6,"deckID":10,"ordinal":0,"scheduling":{}},{"id":8,"noteID":6,"deckID":10,"ordinal":1,"scheduling":{}},{"id":9,"noteID":6,"deckID":20,"ordinal":0,"scheduling":{}}],"media":[],"warnings":[]}"#
        return try JSONDecoder().decode(AnkiCollection.self, from: Data(json.utf8))
    }

    private var migrationKey: String { "anki:fixture:card:30" }
    private var migrationDeckID: String { "anki:fixture:deck:40" }

    private func ratingHistory() -> [AnkiReviewLogEntry] {
        let base: Int64 = 1_700_000_000_000
        let ratings = [1, 3, 3, 2, 3]
        return ratings.enumerated().map { index, ease in
            AnkiReviewLogEntry(id: base + Int64(index) * 86_400_000, cardID: 30,
                updateSequenceNumber: Int64(index), ease: ease, interval: Int64(max(1, index * 2)),
                previousInterval: Int64(max(0, (index - 1) * 2)), factor: 2500,
                answerTimeMilliseconds: 500, type: index < 2 ? 0 : 1)
        }
    }

    private func migrationCollection(type: Int, queue: Int, due: Int64, interval: Int64, reps: Int,
                                     lapses: Int = 0, left: Int64 = 0, history: [AnkiReviewLogEntry],
                                     creation: Int64? = nil) -> AnkiCollection {
        let card = AnkiCard(id: 30, noteID: 10, deckID: 40, ordinal: 0,
            scheduling: ["type": Int64(type), "queue": Int64(queue), "due": due, "ivl": interval,
                         "factor": 2500, "reps": Int64(reps), "lapses": Int64(lapses), "left": left,
                         "odue": 0, "odid": 0, "flags": 0], reviewHistory: history)
        return AnkiCollection(decks: [.init(id: 40, name: "Deck")], noteTypes: [], notes: [],
            cards: [card], creationTime: creation)
    }
}

@MainActor private final class MemoryReviews: ReviewPersisting {
    private var progress = StudyProgressStore(records: [:])
    func load() async throws -> StudyProgressStore { progress }
    func save(_ value: StudyProgressStore) async throws { progress = value }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> StudyProgressStore { progress }
}

private actor MemoryAnkiLibrary: AnkiLibraryPersisting {
    private let summaries: [AnkiImportSummary]
    private let collections: [String: AnkiCollection]
    private let collectionError: Error?
    private(set) var markedVersions: [String: String] = [:]

    init(summaries: [AnkiImportSummary], collections: [String: AnkiCollection] = [:], collectionError: Error? = nil) {
        self.summaries = summaries
        self.collections = collections
        self.collectionError = collectionError
    }

    func load() async throws -> [AnkiImportSummary] { summaries }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> [AnkiImportSummary] { summaries }
    func importPackage(_ url: URL) async throws -> AnkiImportResult { throw AnkiImportError.invalid("не поддерживается") }
    func deleteImport(id: String) async throws {}
    func markSchedulingMigration(importID: String, version: String) async throws { markedVersions[importID] = version }
    func collection(_ summary: AnkiImportSummary) async throws -> AnkiCollection {
        if let collectionError { throw collectionError }
        guard let collection = collections[summary.id] else { throw AnkiImportError.invalid("коллекция отсутствует") }
        return collection
    }
    func mediaDirectory(_ summary: AnkiImportSummary) async throws -> URL { FileManager.default.temporaryDirectory }
}
