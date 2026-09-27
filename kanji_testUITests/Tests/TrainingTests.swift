import XCTest

final class TrainingTests: UITestCase {
    func testDrawingCanvasAcceptsAndClearsStrokes() {
        launch()
        openFirstDeck()
        startTraining()

        let canvas = element(ID.Drawing.canvas)
        let undo = element(ID.Drawing.undo)
        step(.drawStroke, until: { undo.isEnabled }) { canvas.drawStroke() }
        step(.drawStroke, until: { !undo.isEnabled }) { element(ID.Drawing.clear).tap() }
    }

    func testSpeakButtonRequestsSpeech() {
        launch()
        openFirstDeck()
        startTraining()

        let speak = element(ID.Training.speak)
        XCTAssertEqual(speak.value as? String ?? "", "", "Speech was requested before the tap")
        step(.speak, until: { !(speak.value as? String ?? "").isEmpty }) { speak.tap() }
    }

    func testRevealAndRateAdvancesQueue() {
        launch()
        openFirstDeck()
        startTraining()

        revealAndRateGood()
    }

    func testExitTrainingReturnsToDeckThenStart() {
        launch()
        openFirstDeck()
        startTraining()

        exitTraining()
        tap(ID.Preview.back, .backToStart, expecting: ID.Start.search)
    }
}

extension XCUIElement {
    /// A short diagonal stroke inside the element.
    func drawStroke() {
        let from = coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        let to = coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: to)
    }
}
