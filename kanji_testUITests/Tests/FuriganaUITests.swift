import XCTest

final class FuriganaUITests: UITestCase {
    func testOfflineExampleShowsNativeFurigana() {
        launch()
        openExample()
        XCTAssertTrue(element(ID.Examples.furigana).exists)
        XCTAssertEqual(element(ID.Examples.furigana).label, "学校だよ。")
    }

    func testFuriganaSettingPersistsAndShowsOriginalText() {
        launch()
        tap(ID.Start.settings, .openDeck, expecting: ID.Settings.furigana)
        let toggle = element(ID.Settings.furigana)
        XCTAssertEqual(toggle.value as? String, "1")
        step(.selectCard, until: { toggle.value as? String == "0" }) { toggle.tap() }
        tap(ID.Settings.done, .backToStart, expecting: ID.Start.search)
        relaunchKeepingState()
        openExample(showsFurigana: false)
        XCTAssertFalse(element(ID.Examples.furigana).exists)
        XCTAssertEqual(element(ID.Examples.plain).label, "学校だよ。")
    }

    private func openExample(showsFurigana: Bool = true) {
        openFirstDeck()
        tap(ID.Preview.tile, .openSearchResult, expecting: ID.Preview.practiceCard)
        let target = element(showsFurigana ? ID.Examples.furigana : ID.Examples.plain)
        for _ in 0..<8 where !target.exists { app.swipeUp() }
        step(.openSearchResult, until: target) {}
    }
}
