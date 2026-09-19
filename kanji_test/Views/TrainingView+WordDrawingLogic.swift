import SwiftUI

extension TrainingView {
    func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) {
        let shouldReveal = drawingSession.advanceWordKanjiOrCheck(wordCard)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    func selectWordKanji(at index: Int, in wordCard: WordStudyCard) {
        drawingSession.selectWordKanji(at: index, in: wordCard)
    }

    var currentWordFeedback: [StrokeFeedback] {
        drawingSession.currentWordFeedback
    }

    func saveCurrentWordDrawing() {
        drawingSession.saveCurrentWordDrawing()
    }

    func evaluateWordParts(_ wordCard: WordStudyCard) -> [[StrokeFeedback]] {
        drawingSession.evaluateWordParts(wordCard)
    }

    func flattenedWordFeedback(for wordCard: WordStudyCard) -> [StrokeFeedback] {
        drawingSession.flattenedWordFeedback(for: wordCard)
    }

    func undoCurrentWordStroke(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        drawingSession.undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
    }

    func clearCurrentWordDrawing(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        drawingSession.clearCurrentWordDrawing(wordCard, currentKanji: currentKanji)
    }

    func storeCurrentWordFeedback(_ items: [StrokeFeedback], in wordCard: WordStudyCard) {
        drawingSession.storeCurrentWordFeedback(items, in: wordCard)
    }
}
