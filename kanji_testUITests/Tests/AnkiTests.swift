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
        openImportedDeck()
        XCTAssertEqual(counters(of: ID.Preview.start), countersAfterStudy, "Progress must survive relaunch")
    }

    private func openImportedDeck() {
        tap(ID.Start.sectionAnki, .openAnki, expecting: ID.Anki.importPackage)
        step(.importAnki, until: element(ID.Deck.row)) {}
        tap(ID.Deck.row, .openDeck, expecting: ID.Preview.start)
    }
}
