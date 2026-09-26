import SwiftUI

extension TrainingView {
    func kanaDrawingPanel(for kanaCard: KanaStudyCard, panelHeight: CGFloat) -> some View {
        let expectedCard = kanjiCard(for: kanaCard)

        return KanjiDrawingPanel(
            drawingSession: drawingSession,
            expectedCard: expectedCard,
            panelHeight: panelHeight,
            isGuided: trainingSession.isGuidedSingleKanjiPractice,
            onStrokeFinished: { handleGuidedStrokeFinished(expectedCard) },
            onReveal: { revealDrawingAnswer() },
            onAdvance: { advanceGuidedStrokeOrReveal(expectedCard) }
        ) {
            reviewControls()
        }
    }
}
