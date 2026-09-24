import SwiftUI

extension TrainingView {
    func ankiTrainingView(for card: AnkiStudyCard) -> some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(spacing: 16) {
                headerControls()
                AnkiCardContentView(card: card, answer: drawingSession.isAnswerVisible,
                                    translationState: translationState, language: trainingSession.options.meaningLanguage)
                    .id("\(card.id)-\(trainingSession.scrollToTopToken)")
                learningStatusLabel(forReviewKey: card.reviewKey)
                VStack(spacing: 12) {
                    Button(drawingSession.isAnswerVisible ? "Показать вопрос" : "Показать ответ") {
                        drawingSession.isAnswerVisible.toggle()
                    }.buttonStyle(.borderedProminent).tint(AppPalette.accent)
                    reviewControls()
                }.padding(16).appSurfaceCard()
            }.padding(20).foregroundStyle(AppPalette.text)
        }
    }
}
