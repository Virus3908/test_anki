import SwiftUI

extension TrainingView {
    func wordDrawingPanel(for wordCard: WordStudyCard, currentKanji: KanjiCard, panelHeight: CGFloat) -> some View {
        WordDrawingPanel(
            drawingSession: drawingSession,
            wordCard: wordCard,
            currentKanji: currentKanji,
            panelHeight: panelHeight,
            isGuided: trainingSession.isGuidedSingleKanjiPractice,
            onStrokeFinished: { handleGuidedWordStrokeFinished(wordCard) },
            onReveal: { revealDrawingAnswer() },
            onAdvance: { advanceWordKanjiOrCheck(wordCard) }
        ) {
            reviewControls()
        }
    }
}
