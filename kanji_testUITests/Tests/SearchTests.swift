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
}
