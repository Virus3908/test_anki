import XCTest
@testable import kanji_test

@MainActor
final class CustomTrainingSessionTests: XCTestCase {
    private let deck = StudyDeck(id: "test:deck", title: "Test deck", mode: .kanji)
    private let ids = ["a", "b", "c", "d", "e"]

    private func makeSession(
        deckID: String = "test:deck",
        cardTypes: [TrainingCardType]? = nil
    ) -> CustomTrainingSession {
        let defaults = UserDefaults(suiteName: "custom-training-tests-\(UUID().uuidString)")!
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        if let cardTypes {
            settings.updateOptions(for: deckID) { $0.cardTypes = cardTypes }
        }
        return CustomTrainingSession(catalog: StudyCardCatalog(), settings: settings)
    }

    func testStartBuildsQueueAndResetsState() {
        let session = makeSession()

        session.start(deck: deck, cardIDs: ids)

        XCTAssertEqual(Set(session.queue), Set(ids))
        XCTAssertEqual(session.queue.count, ids.count)
        XCTAssertEqual(session.selectedIDs, Set(ids))
        XCTAssertTrue(session.isRunning)
        XCTAssertNotNil(session.currentID)
        XCTAssertFalse(session.isAnswerVisible)
        XCTAssertEqual(session.answersCount, 0)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.round, 1)
    }

    func testStartWithEmptySelectionIsNoOp() {
        let session = makeSession()

        session.start(deck: deck, cardIDs: [])

        XCTAssertFalse(session.isRunning)
        XCTAssertNil(session.currentID)
    }

    func testQueueNeverDrains() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)

        for _ in 0..<(ids.count * 4) {
            session.submit(.good)
        }

        XCTAssertEqual(session.queue.count, ids.count)
        XCTAssertTrue(session.isRunning)
    }

    func testAgainRepeatsBeforeGoodAnsweredCards() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)
        let first = session.currentID!
        session.submit(.good)
        let second = session.currentID!
        session.submit(.good)
        let third = session.currentID!
        session.submit(.again)

        // Не показанные в круге карточки остаются впереди любых повторов…
        let unseen = Set(ids).subtracting([first, second, third])
        XCTAssertEqual(Set(session.queue.prefix(unseen.count)), unseen)
        // …а «снова» возвращается раньше карточек, отвеченных «норм».
        let againPosition = session.queue.firstIndex(of: third)!
        XCTAssertLessThan(againPosition, session.queue.firstIndex(of: first)!)
        XCTAssertLessThan(againPosition, session.queue.firstIndex(of: second)!)
    }

    func testFirstPassShowsEverySelectedCardOnce() {
        let manyIDs = (0..<12).map { "k\($0)" }
        let session = makeSession()
        session.start(deck: deck, cardIDs: manyIDs)
        var shown: Set<String> = []

        // «Трудно» — худший случай для голодания очереди: интервал не растёт.
        for _ in manyIDs {
            let current = session.currentID!
            XCTAssertFalse(shown.contains(current))
            shown.insert(current)
            session.submit(.hard)
        }

        XCTAssertEqual(shown, Set(manyIDs))
    }

    func testRepeatsNeverOvertakeUnseenCards() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)
        var shown: Set<String> = []

        for _ in ids {
            shown.insert(session.currentID!)
            session.submit(.hard)
            let unseen = Set(ids).subtracting(shown)
            if !unseen.isEmpty {
                XCTAssertEqual(Set(session.queue.prefix(unseen.count)), unseen)
            }
        }
    }

    func testFirstGoodPutsCardAtBackOfQueue() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)
        let current = session.currentID!

        session.submit(.good)

        XCTAssertEqual(session.queue.last, current)
        XCTAssertNotEqual(session.currentID, current)
    }

    func testRevealAnswerTogglesAndSubmitHides() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)

        session.revealAnswer()
        XCTAssertTrue(session.isAnswerVisible)

        session.submit(.good)
        XCTAssertFalse(session.isAnswerVisible)
    }

    func testStatsAndStreaks() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)

        session.submit(.good)
        session.submit(.hard)
        session.submit(.easy)
        XCTAssertEqual(session.currentStreak, 3)
        XCTAssertEqual(session.bestStreak, 3)

        session.submit(.again)
        XCTAssertEqual(session.answersCount, 4)
        XCTAssertEqual(session.correctCount, 3)
        XCTAssertEqual(session.currentStreak, 0)
        XCTAssertEqual(session.bestStreak, 3)
        XCTAssertEqual(session.accuracy, 0.75, accuracy: 0.0001)
    }

    func testRoundAdvancesAfterEveryCardSeen() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)

        for _ in 0..<ids.count { session.submit(.good) }
        XCTAssertEqual(session.round, 2)

        for _ in 0..<ids.count { session.submit(.good) }
        XCTAssertEqual(session.round, 3)
    }

    func testSingleCardSessionIsEndless() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ["solo"])

        for _ in 0..<10 { session.submit(.again) }

        XCTAssertEqual(session.queue, ["solo"])
        XCTAssertEqual(session.currentID, "solo")
        XCTAssertTrue(session.isRunning)
    }

    func testStopEndsSession() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)
        session.revealAnswer()

        session.stop()

        XCTAssertTrue(session.queue.isEmpty)
        XCTAssertFalse(session.isRunning)
        XCTAssertNil(session.currentID)
        XCTAssertFalse(session.isAnswerVisible)
    }

    func testToggleAndSetSelection() {
        let session = makeSession()

        session.toggle("a")
        session.toggle("b")
        session.toggle("a")
        XCTAssertEqual(session.selectedIDs, ["b"])

        session.setSelection(["c", "d"])
        XCTAssertEqual(session.selectedIDs, ["c", "d"])
    }

    func testSelectionLifecycle() {
        let session = makeSession()

        session.beginSelection()
        XCTAssertTrue(session.isSelecting)

        session.cancelSelection()
        XCTAssertFalse(session.isSelecting)
        XCTAssertTrue(session.selectedIDs.isEmpty)

        session.setSelection(Set(ids))
        session.beginSelection()
        session.finishSelection()
        XCTAssertFalse(session.isSelecting)
        XCTAssertEqual(session.selectedIDs, Set(ids))
    }

    // MARK: - Card types

    func testDefaultCardTypeIsDrawing() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)

        XCTAssertEqual(session.currentCardType, .drawing)
    }

    func testConfiguredCardTypeComesFromDeckOptions() {
        let session = makeSession(cardTypes: [.choice])
        session.start(deck: deck, cardIDs: ids)

        XCTAssertEqual(session.currentCardType, .choice)
    }

    func testCurrentCardTypeMatchesResolver() {
        let configured = TrainingCardType.allowed(for: .kanji)
        let session = makeSession(cardTypes: configured)
        session.start(deck: deck, cardIDs: ids)
        let effective = TrainingCardType.effectiveTypes(configured: configured, mode: .kanji)

        XCTAssertEqual(
            session.currentCardType,
            TrainingCardType.resolve(
                cardID: session.currentID!,
                deckID: deck.id,
                date: session.studyDay,
                allowed: effective
            )
        )
    }

    func testCardTypeOfSameCardSurvivesRequeue() {
        let session = makeSession(cardTypes: [.choice, .typed, .flip])
        session.start(deck: deck, cardIDs: ["solo"])
        let type = session.currentCardType

        for _ in 0..<3 { session.submit(.good) }

        XCTAssertEqual(session.currentID, "solo")
        XCTAssertEqual(session.currentCardType, type)
    }

    func testWordsDeckCannotUseDrawingType() {
        let wordsDeck = StudyDeck(id: "test:words", title: "Words", mode: .words)
        let session = makeSession(deckID: wordsDeck.id, cardTypes: [.drawing])
        session.start(deck: wordsDeck, cardIDs: ids)

        XCTAssertEqual(session.currentCardType, .flip)
    }

    func testAnkiDeckAlwaysResolvesDrawing() {
        let ankiDeck = StudyDeck(id: "test:anki", title: "Anki", mode: .anki)
        let session = makeSession(deckID: ankiDeck.id, cardTypes: [.choice])
        session.start(deck: ankiDeck, cardIDs: ids)

        XCTAssertEqual(session.currentCardType, .drawing)
    }

    func testRecallMeaningPoolExcludesCurrentCardMeanings() {
        let defaults = UserDefaults(suiteName: "custom-training-pool-\(UUID().uuidString)")!
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        let catalog = StudyCardCatalog()
        let sourceIDs = catalog.register([
            kanjiCard("日", ["солнце", "день"]),
            kanjiCard("月", ["луна", "месяц"]),
            kanjiCard("水", ["вода"])
        ])
        let session = CustomTrainingSession(catalog: catalog, settings: settings)
        session.start(deck: deck, cardIDs: sourceIDs)
        // Очередь перемешивается, поэтому текущая карточка не фиксирована.
        let current = session.currentKanjiCard!
        let allMeanings: Set<String> = ["солнце", "день", "луна", "месяц", "вода"]

        let pool = session.recallMeaningPool(excluding: session.currentID!)

        XCTAssertEqual(Set(pool), allMeanings.subtracting(current.meanings))
    }

    private func kanjiCard(_ character: String, _ meanings: [String]) -> KanjiCard {
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
}
