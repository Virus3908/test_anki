import XCTest

final class SearchTests: UITestCase {
    func testSearchFindsWordAndOpensResult() {
        launch()
        tap(ID.Start.search, .openSearch, expecting: ID.Search.field)

        let field = element(ID.Search.field)
        step(.searchResults, until: element(ID.Search.result)) {
            field.tap()
            field.typeText("日")
        }

        tap(ID.Search.result, .openSearchResult, expecting: ID.Preview.practiceCard)
    }
    func testImportedSearchPreservesNavigationAndLoadsSelectedCard() {
        launch(importingAnkiFixture: true)
        openImportedLibrary()
        tap(ID.Start.search, .openSearch, expecting: ID.Search.field)
        let field = element(ID.Search.field)
        step(.searchResults, until: element(ID.Search.result)) {
            field.tap()
            field.typeText("UI Test Deck")
        }
        tap(ID.Search.result, .openSearchResult, expecting: ID.Preview.practiceCard)
        XCTAssertTrue(app.staticTexts["山"].exists)
        let next = app.buttons["Следующая карточка"]
        step(.openSearchResult, until: { [unowned self] in
            app.staticTexts["川"].exists && element(ID.Preview.practiceCard).exists
        }) { next.tap() }
    }

}
