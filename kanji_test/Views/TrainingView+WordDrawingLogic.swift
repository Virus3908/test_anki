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
}
