import XCTest
@testable import kanji_test

@MainActor
final class CardSearchViewModelTests: XCTestCase {
    func testNewQueryClearCancelAndReopenNeverPublishStaleResults() async throws {
        let app = StudyAppViewModel()
        let model = CardSearchViewModel(scope: .words, translationState: app.translationState)
        await model.prepare()
        XCTAssertNil(model.loadError)
        let old = Task { await model.updateResults(for: "a") }
        await Task.yield()
        await model.updateResults(for: "nihon")
        let expected = model.wordResults.map(\.reviewKey)
        let total = model.totalFound
        XCTAssertGreaterThan(total, 0)
        await old.value
        XCTAssertEqual(model.wordResults.map(\.reviewKey), expected)
        XCTAssertEqual(model.totalFound, total)

        let clearing = Task { await model.updateResults(for: "a") }
        await Task.yield()
        await model.updateResults(for: "")
        await clearing.value
        XCTAssertTrue(model.wordResults.isEmpty)
        XCTAssertEqual(model.totalFound, 0)

        let closing = Task { await model.updateResults(for: "a") }
        await Task.yield()
        model.cancelSearch()
        closing.cancel()
        await closing.value
        XCTAssertTrue(model.wordResults.isEmpty)
        await model.prepare()
        await model.updateResults(for: "nihon")
        XCTAssertEqual(model.wordResults.map(\.reviewKey), expected)
    }
}
