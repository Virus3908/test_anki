import SwiftUI

extension TrainingView {
    @ViewBuilder func kanaDrawingPanel(for kanaCard: KanaStudyCard, panelHeight: CGFloat) -> some View {
        if kanaCard.drawingCards.count > 1 {
            let word = kanaCard.drawingWordCard
            if let current = currentWordKanjiCard(for: word) {
                wordDrawingPanel(for: word, currentKanji: current, panelHeight: panelHeight)
            }
        } else if let expectedCard = kanaCard.drawingCards.first {
            KanjiDrawingPanel(
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
}
