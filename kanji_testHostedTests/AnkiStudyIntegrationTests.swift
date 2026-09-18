import XCTest
import AnkiImport
@testable import kanji_test

@MainActor
final class AnkiStudyIntegrationTests: XCTestCase {
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
        navigation.route = .ankiDeck(model.decks[1])
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
}

private actor MemoryReviews: ReviewPersisting {
    private var progress = StudyProgressStore(records: [:])
    func load() async throws -> StudyProgressStore { progress }
    func save(_ value: StudyProgressStore) async throws { progress = value }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> StudyProgressStore { progress }
}
