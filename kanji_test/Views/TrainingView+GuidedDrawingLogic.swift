import SwiftUI

extension TrainingView {
    func handleGuidedStrokeFinished(_ card: KanjiCard) {
        let shouldReveal = drawingSession.handleGuidedStrokeFinished(
            card,
            isGuided: trainingSession.isGuidedSingleKanjiPractice
        )
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    func handleGuidedWordStrokeFinished(_ wordCard: WordStudyCard) {
        let shouldReveal = drawingSession.handleGuidedWordStrokeFinished(
            wordCard,
            isGuided: trainingSession.isGuidedSingleKanjiPractice
        )
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    func advanceGuidedStrokeOrReveal(_ card: KanjiCard) {
        let shouldReveal = drawingSession.advanceGuidedStrokeOrReveal(
            card,
            isGuided: trainingSession.isGuidedSingleKanjiPractice
        )
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    func revealDrawingAnswer() {
        withAnimation(.easeInOut(duration: 0.24)) {
            drawingSession.revealAnswer()
        }
    }
}
