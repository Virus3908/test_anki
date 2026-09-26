import XCTest
@testable import kanji_test

@MainActor
final class CustomTrainingSessionTests: XCTestCase {
    private let deck = StudyDeck(id: "test:deck", title: "Test deck", mode: .kanji)
    private let ids = ["a", "b", "c", "d", "e"]

    private func makeSession() -> CustomTrainingSession {
        CustomTrainingSession(catalog: StudyCardCatalog())
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

    func testAgainReinsertsCardSoonerThanGood() {
        let session = makeSession()
        session.start(deck: deck, cardIDs: ids)
        let current = session.currentID!

        session.submit(.again)
        XCTAssertEqual(session.queue[2], current)

        let next = session.currentID!
        session.submit(.good)
        XCTAssertEqual(session.queue.last, next)
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
}
