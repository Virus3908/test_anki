import SwiftUI

extension TrainingView {
    func guidedExpectedStrokes(for card: KanjiCard) -> [KanjiStroke] {
        drawingSession.guidedExpectedStrokes(for: card)
    }

    func expectedStrokesForCurrentCard(_ card: KanjiCard) -> [KanjiStroke] {
        drawingSession.expectedStrokes(for: card, isGuided: trainingSession.isGuidedSingleKanjiPractice)
    }

    func expectedStrokesForCurrentWordKanji(_ card: KanjiCard) -> [KanjiStroke] {
        drawingSession.expectedWordStrokes(
            for: card,
            isGuided: trainingSession.isGuidedSingleKanjiPractice
        )
    }

    func nextGuidedStrokeLimit(for card: KanjiCard) -> Int {
        drawingSession.nextGuidedStrokeLimit(for: card)
    }

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
