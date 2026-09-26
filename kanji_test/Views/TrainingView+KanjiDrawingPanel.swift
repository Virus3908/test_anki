import SwiftUI

extension TrainingView {
    func drawingPanel(for card: KanjiCard, panelHeight: CGFloat) -> some View {
        KanjiDrawingPanel(
            drawingSession: drawingSession,
            expectedCard: card,
            panelHeight: panelHeight,
            isGuided: trainingSession.isGuidedSingleKanjiPractice,
            onStrokeFinished: { handleGuidedStrokeFinished(card) },
            onReveal: { revealDrawingAnswer() },
            onAdvance: { advanceGuidedStrokeOrReveal(card) }
        ) {
            reviewControls()
        }
    }
}
