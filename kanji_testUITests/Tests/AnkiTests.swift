import XCTest

final class AnkiTests: UITestCase {
    /// Cards in `Fixtures/ui-test-deck.apkg`.
    private let fixtureCardCount = 3

    func testImportedDeckShowsItsCards() {
        launch(importingAnkiFixture: true)
        openImportedDeck()

        XCTAssertEqual(elements(ID.Preview.tile).count, fixtureCardCount)
    }

    func testRatedCardPersistsAcrossRelaunch() {
        launch(importingAnkiFixture: true)
        openImportedDeck()
        XCTAssertEqual(counters(of: ID.Preview.start)["new"], fixtureCardCount)

        startTraining()
        revealAndRateGood()
        exitTraining()
        let countersAfterStudy = counters(of: ID.Preview.start)
        XCTAssertLessThan(countersAfterStudy["new"] ?? .max, fixtureCardCount, "Rated card must leave the new pile")

        relaunchKeepingState()
        openImportedDeck(expectingImportNotice: false)
        XCTAssertEqual(counters(of: ID.Preview.start), countersAfterStudy, "Progress must survive relaunch")
    }

    func testCompletingFixtureStudyDayReturnsToDeck() {
        launch(importingAnkiFixture: true)
        openImportedDeck()
        startTraining()
        for _ in 0..<fixtureCardCount {
            let rate = element(ID.Training.rateEasy)
            step(.revealCard, until: { rate.isEnabled }) { element(ID.Training.reveal).tap() }
            let remaining = counters(of: ID.Training.progress)["remaining"] ?? .max
            step(.rateCard, until: { [unowned self] in
                element(ID.Completion.title).exists ||
                    (counters(of: ID.Training.progress)["remaining"] ?? .max) < remaining
            }) { rate.tap() }
        }
        XCTAssertTrue(element(ID.Completion.title).exists)
        tap(ID.Completion.stay, .backToStart, expecting: ID.Preview.start)
    }

    private func openImportedDeck(expectingImportNotice: Bool = true) {
        openImportedLibrary(expectingImportNotice: expectingImportNotice)
        tap(ID.Deck.row, .openDeck, expecting: ID.Preview.start)
    }
}
