import SwiftUI

extension TrainingView {
    func kanjiCard(for kanaCard: KanaStudyCard) -> KanjiCard {
        KanjiCard(
            kanji: kanaCard.character,
            meanings: [kanaCard.reading],
            onyomi: [],
            kunyomi: [kanaCard.reading],
            examples: [],
            source: KanjiSource(name: "KanjiVG", file: "kana", license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"),
            strokes: kanaCard.strokes,
            translationState: "ru-system"
        )
    }

    func undoCurrentStroke(expected card: KanjiCard? = nil) {
        let shouldHideAnswer = drawingSession.undoStroke(expected: card)
        if shouldHideAnswer {
            withAnimation(.easeInOut(duration: 0.18)) {
                drawingSession.hideAnswer()
            }
        }
    }

    func clearCurrentDrawing(expected card: KanjiCard) {
        drawingSession.clearDrawing(expected: card)
    }

}
