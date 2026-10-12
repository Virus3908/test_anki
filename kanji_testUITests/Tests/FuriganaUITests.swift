import XCTest

final class FuriganaUITests: UITestCase {
    func testOfflineExampleShowsNativeFurigana() {
        launch()
        openExample()
        XCTAssertTrue(element(ID.Examples.furigana).exists)
        XCTAssertEqual(element(ID.Examples.furigana).label, "学校だよ。")
        assertSourceBesideShortSentence(ID.Examples.furigana)
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
        assertSourceBesideShortSentence(ID.Examples.plain)
    }

    private func assertSourceBesideShortSentence(_ sentenceID: String) {
        let sentence = element(sentenceID)
        let source = element(ID.Examples.source)
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(source.isHittable)
        // The offline fixture is five Japanese characters, not a full row.
        // Check actual on-screen frames, including the real attribution Menu.
        XCTAssertLessThan(sentence.frame.width, 150)
        XCTAssertGreaterThanOrEqual(source.frame.minX, sentence.frame.maxX - 1)
        XCTAssertLessThanOrEqual(source.frame.minX - sentence.frame.maxX, 12)
    }

    private func openExample(showsFurigana: Bool = true) {
        openFirstDeck()
        tap(ID.Preview.tile, .openSearchResult, expecting: ID.Preview.practiceCard)
        let target = element(showsFurigana ? ID.Examples.furigana : ID.Examples.plain)
        for _ in 0..<8 where !target.exists { app.swipeUp() }
        step(.openSearchResult, until: target) {}
    }
}
