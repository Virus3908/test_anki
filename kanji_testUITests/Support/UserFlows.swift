import XCTest

/// Reusable user journeys built only from contract identifiers.
extension UITestCase {
    typealias ID = AccessibilityID

    static let sections = [
        ID.Start.sectionKanji,
        ID.Start.sectionWords,
        ID.Start.sectionKana,
        ID.Start.sectionAnki,
    ]

    func openImportedLibrary(expectingImportNotice: Bool = true) {
        let notice = app.alerts["Импорт Anki"]
        let section = element(ID.Start.sectionAnki)
        step(.openAnki, until: { section.isSelected || notice.exists }) { section.tap() }
        if expectingImportNotice {
            step(.importAnki, until: notice) {}
            XCTAssertTrue(notice.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "3 карточек")).firstMatch.exists,
                          "The fixture must finish importing successfully")
            step(.importAnki, until: { !notice.exists }) { notice.buttons["Понятно"].tap() }
        }
        step(.openAnki, until: element(ID.Anki.importPackage)) {}
        step(.importAnki, until: element(ID.Deck.row)) {}
    }

    /// Start screen → section → first deck preview.
    func openFirstDeck(in section: String = ID.Start.sectionKanji) {
        tap(section, .switchSection, expecting: ID.Deck.row)
        tap(ID.Deck.row, .openDeck, expecting: ID.Preview.start)
    }

    /// Deck preview → training with a card on screen.
    func startTraining() {
        tap(ID.Preview.start, .startTraining, expecting: ID.Training.reveal)
    }

    /// Reveal the current card and rate it «Good»; returns once the answer is registered.
    func revealAndRateGood() {
        let answeredBefore = counters(of: ID.Training.progress)["answered"] ?? 0
        let rate = element(ID.Training.rateGood)
        step(.revealCard, until: { rate.isEnabled }) { element(ID.Training.reveal).tap() }
        step(.rateCard, until: { [unowned self] in
            (counters(of: ID.Training.progress)["answered"] ?? 0) > answeredBefore
        }) { rate.tap() }
    }

    /// Training → back to the deck preview.
    func exitTraining(expecting next: String = ID.Preview.start) {
        tap(ID.Training.exit, .exitTraining, expecting: next)
    }
}
