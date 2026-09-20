import CoreGraphics
import XCTest
@testable import kanji_test

@MainActor
final class DrawingSessionViewModelTests: XCTestCase {
    func testGuidedWordRevealsStrokesProgressively() {
        let session = DrawingSessionViewModel()
        let card = kanjiCard("一", strokes: [
            stroke(order: 1, start: [10, 20], end: [80, 20]),
            stroke(order: 2, start: [10, 50], end: [80, 50])
        ])

        XCTAssertEqual(session.expectedWordStrokes(for: card, isGuided: true).map(\.order), [1])

        session.drawnStrokes = [[CGPoint(x: 10, y: 20), CGPoint(x: 45, y: 20), CGPoint(x: 80, y: 20)]]
        let shouldReveal = session.handleGuidedWordStrokeFinished(
            wordCard("一", kanjiCards: [card]),
            isGuided: true
        )

        XCTAssertFalse(shouldReveal)
        XCTAssertEqual(session.expectedWordStrokes(for: card, isGuided: true).map(\.order), [1, 2])
    }

    func testGuidedWordAdvancesToNextKanjiBeforeRevealingAnswer() {
        let session = DrawingSessionViewModel()
        let first = kanjiCard("一", strokes: [stroke(order: 1, start: [10, 20], end: [80, 20])])
        let second = kanjiCard("二", strokes: [stroke(order: 1, start: [10, 50], end: [80, 50])])
        let word = wordCard("一二", kanjiCards: [first, second])

        session.drawnStrokes = [[CGPoint(x: 10, y: 20), CGPoint(x: 45, y: 20), CGPoint(x: 80, y: 20)]]

        XCTAssertFalse(session.handleGuidedWordStrokeFinished(word, isGuided: true))
        XCTAssertEqual(session.currentWordKanjiIndex, 1)
        XCTAssertFalse(session.isAnswerVisible)
        XCTAssertEqual(session.expectedWordStrokes(for: second, isGuided: true).map(\.order), [1])
    }

    func testRegularWordPracticeKeepsStrokesHiddenUntilAnswer() {
        let session = DrawingSessionViewModel()
        let card = kanjiCard("一", strokes: [stroke(order: 1, start: [10, 20], end: [80, 20])])

        XCTAssertTrue(session.expectedWordStrokes(for: card, isGuided: false).isEmpty)

        session.revealAnswer()

        XCTAssertEqual(session.expectedWordStrokes(for: card, isGuided: false).map(\.order), [1])
    }

    private func wordCard(_ word: String, kanjiCards: [KanjiCard]) -> WordStudyCard {
        WordStudyCard(word: word, reading: "", meaning: "", examples: [], kanjiCards: kanjiCards)
    }

    private func kanjiCard(_ kanji: String, strokes: [KanjiStroke]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: [],
            onyomi: [],
            kunyomi: [],
            examples: [],
            source: KanjiSource(name: "Test", file: "test", license: "Test"),
            strokes: strokes
        )
    }

    private func stroke(order: Int, start: [Double], end: [Double]) -> KanjiStroke {
        KanjiStroke(
            order: order,
            pathData: "M \(start[0]) \(start[1]) L \(end[0]) \(end[1])",
            start: start,
            end: end,
            axis: .horizontal
        )
    }
}
