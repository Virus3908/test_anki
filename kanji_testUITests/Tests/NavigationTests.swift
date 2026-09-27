import XCTest

final class NavigationTests: UITestCase {
    func testSectionSwitcherShowsEachSection() {
        launch()
        let contentBySection = [
            ID.Start.sectionKanji: ID.Deck.row,
            ID.Start.sectionWords: ID.Deck.row,
            ID.Start.sectionKana: ID.Deck.row,
            ID.Start.sectionAnki: ID.Anki.importPackage,
        ]

        for section in Self.sections {
            let button = element(section)
            step(.switchSection, until: { [unowned self] in button.isSelected && element(contentBySection[section]!).exists }) {
                button.tap()
            }
        }
    }

    func testDeckOpensAndReturnsToStart() {
        launch()
        openFirstDeck()

        tap(ID.Preview.back, .backToStart, expecting: ID.Start.search)
    }
}
