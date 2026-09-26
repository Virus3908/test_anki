import SwiftUI

extension TrainingView {
    func reviewControls() -> some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    moveToPreviousCard()
                } label: {
                    Label(trainingSession.isGuidedSingleKanjiPractice ? "Назад" : "Отменить ответ",
                          systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .disabled(!trainingSession.canGoBack || trainingSession.isPreparingCard)
                Spacer()
                if trainingSession.isGuidedSingleKanjiPractice {
                    sessionAnswerLabel()
                    Button("Дальше", systemImage: "chevron.right") { moveToNextCard() }
                        .disabled(!trainingSession.canGoForward)
                }
            }
            TrainingRatingBar(
                isAnswerVisible: drawingSession.isAnswerVisible,
                isPreparingCard: trainingSession.isPreparingCard,
                intervalLabel: { trainingSession.intervalLabel(for: $0) }
            ) { rating in
                switch practiceMode {
                case .kanji:
                    if let card = cards[safe: trainingSession.currentIndex] { applyReview(rating, to: card) }
                case .words: applyWordReview(rating)
                case .kana: applyKanaReview(rating)
                case .anki: applyAnkiReview(rating)
                }
            }
        }
    }

    func currentSessionRating() -> ReviewRating? {
        sessionRating(at: trainingSession.currentIndex)
    }

    func sessionRating(at index: Int) -> ReviewRating? {
        trainingSession.sessionAnswerStates[trainingSession.answerID(for: practiceMode, index: index)]?.rating
    }

    func ratingButtonColor(for rating: ReviewRating, hasFeedback: Bool, isAnswered: Bool) -> Color {
        guard hasFeedback || isAnswered else {
            return AppPalette.mutedText
        }

        return TrainingRatingBar.buttonColor(for: rating)
    }

    @ViewBuilder
    func sessionAnswerLabel() -> some View {
        if let rating = currentSessionRating() {
            Label("Ответ: \(rating.title)", systemImage: rating.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ratingButtonColor(for: rating, hasFeedback: true, isAnswered: true))
        }
    }

}
