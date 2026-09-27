import XCTest

final class CustomTrainingTests: UITestCase {
    func testCardSelection() {
        launch()
        openFirstDeck()
        tap(ID.Preview.custom, .openCustomSelection, expecting: ID.Custom.start)

        let start = element(ID.Custom.start)
        XCTAssertFalse(start.isEnabled)
        step(.selectCard, until: { [unowned self] in selectedCount == 1 }) { element(ID.Preview.tile).tap() }
        step(.selectCard, until: { [unowned self] in selectedCount > 1 }) { element(ID.Custom.selectAll).tap() }
        step(.selectCard, until: { [unowned self] in selectedCount == 0 }) { element(ID.Custom.clear).tap() }
        XCTAssertFalse(start.isEnabled)
    }

    func testCustomTrainingRunsAndExitsToDeck() {
        launch()
        openFirstDeck()
        tap(ID.Preview.custom, .openCustomSelection, expecting: ID.Custom.start)
        step(.selectCard, until: { [unowned self] in selectedCount == 1 }) { element(ID.Preview.tile).tap() }

        tap(ID.Custom.start, .startCustomTraining, expecting: ID.Training.reveal)
        revealAndRateGood()
        exitTraining()
    }

    private var selectedCount: Int {
        counters(of: ID.Custom.start)["selected"] ?? -1
    }
}
