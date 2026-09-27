import XCTest
@testable import kanji_test

@MainActor
final class TrainingSessionCardTypeTests: XCTestCase {
    private static let deckID = "kanji:cardtype-tests"
    private static let wordDeckID = "words:cardtype-tests"

    private static let kanjiCards = [
        kanjiCard("日", ["солнце", "день"]),
        kanjiCard("月", ["луна", "месяц"]),
        kanjiCard("水", ["вода"])
    ]

    private static func kanjiCard(_ character: String, _ meanings: [String]) -> KanjiCard {
        KanjiCard(
            kanji: character,
            meanings: meanings,
            onyomi: [],
            kunyomi: [],
            examples: [],
            source: KanjiSource(name: "test", file: "test.svg", license: "test"),
            strokes: []
        )
    }

    private func makeSession(
        deck: StudyDeck,
        cards: [KanjiCard],
        cardTypes: [TrainingCardType]? = nil,
        guided: Bool = false
    ) async throws -> TrainingSessionViewModel {
        let defaults = UserDefaults(suiteName: "cardtype-tests-\(UUID().uuidString)")!
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        if let cardTypes {
            settings.updateOptions(for: deck.id) { $0.cardTypes = cardTypes }
        }
        let catalog = StudyCardCatalog()
        let sourceIDs = catalog.register(cards)
        let session = TrainingSessionViewModel(
            repository: InMemoryReviewRepository(),
            catalog: catalog,
            settings: settings,
            errors: StorageStatus()
        )
        try await session.loadProgress()
        let started = await session.start(deck: deck, sourceIDs: sourceIDs, guided: guided)
        XCTAssertTrue(started)
        return session
    }

    private func currentCardID(_ session: TrainingSessionViewModel) -> String? {
        session.cards[safe: session.currentIndex]?.id
    }

    func testDefaultCardTypePerMode() async throws {
        let kanjiSession = try await makeSession(deck: StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji), cards: Self.kanjiCards)
        XCTAssertEqual(kanjiSession.currentCardType, .drawing)

        let wordSession = try await makeSession(deck: StudyDeck(id: Self.wordDeckID, title: "Тест", mode: .words), cards: Self.kanjiCards)
        XCTAssertEqual(wordSession.currentCardType, .flip)
    }

    func testConfiguredCardTypeIsRespected() async throws {
        let deck = StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji)
        let flipSession = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: [.flip])
        XCTAssertEqual(flipSession.currentCardType, .flip)

        let mixedSession = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: [.choice, .typed])
        XCTAssertTrue([TrainingCardType.choice, .typed].contains(mixedSession.currentCardType))
    }

    func testWordsConfiguredWithDrawingFallsBackToFlip() async throws {
        let deck = StudyDeck(id: Self.wordDeckID, title: "Тест", mode: .words)
        let session = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: [.drawing])
        XCTAssertEqual(session.currentCardType, .flip)
    }

    func testGuidedSessionAlwaysDraws() async throws {
        let deck = StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji)
        let session = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: [.choice], guided: true)
        XCTAssertEqual(session.currentCardType, .drawing)
    }

    func testCurrentCardTypeMatchesResolverForCurrentCard() async throws {
        let deck = StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji)
        let session = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: Array(TrainingCardType.allowed(for: .kanji)))

        let cardID = try XCTUnwrap(currentCardID(session))
        let expected = TrainingCardType.resolve(
            cardID: cardID,
            deckID: deck.id,
            date: session.state.studyDay ?? Date(),
            allowed: Array(TrainingCardType.allowed(for: .kanji))
        )
        XCTAssertEqual(session.currentCardType, expected)
    }

    func testCardTypeSurvivesReviewRebuild() async throws {
        let deck = StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji)
        let allowed: [TrainingCardType] = [.flip, .choice, .typed]
        let session = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: allowed)

        let firstCardID = try XCTUnwrap(currentCardID(session))
        let typeBefore = session.currentCardType
        await session.submitReview(.again, expectedKey: firstCardID)

        // Тип считается от studyDay сессии, поэтому rebuild не меняет его для той же карточки.
        let sameCardSession = try await makeSession(deck: deck, cards: Self.kanjiCards, cardTypes: allowed)
        XCTAssertEqual(sameCardSession.currentCardType, typeBefore)

        // После ответа тип следующей карточки детерминирован тем же резолвером.
        if let nextCardID = currentCardID(session), nextCardID != firstCardID {
            let expected = TrainingCardType.resolve(
                cardID: nextCardID,
                deckID: deck.id,
                date: session.state.studyDay ?? Date(),
                allowed: allowed
            )
            XCTAssertEqual(session.currentCardType, expected)
        }
    }

    func testRecallMeaningPoolExcludesCurrentCard() async throws {
        let deck = StudyDeck(id: Self.deckID, title: "Тест", mode: .kanji)
        let session = try await makeSession(deck: deck, cards: Self.kanjiCards)

        let cardID = try XCTUnwrap(currentCardID(session))
        let pool = session.recallMeaningPool(excluding: cardID)
        let excludedMeanings = Set(Self.kanjiCards[0].meanings.map(MeaningMatcher.normalized))

        XCTAssertTrue(pool.contains("луна"))
        XCTAssertTrue(pool.contains("вода"))
        XCTAssertTrue(pool.allSatisfy { !excludedMeanings.contains(MeaningMatcher.normalized($0)) })
    }
}

/// In-memory persistence for tests: no files, no backup path.
private final class InMemoryReviewRepository: ReviewPersisting, @unchecked Sendable {
    private var store = StudyProgressStore(records: [:])

    func load() async throws -> StudyProgressStore { store }
    func save(_ value: StudyProgressStore) async throws { store = value }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> StudyProgressStore { store }
}
