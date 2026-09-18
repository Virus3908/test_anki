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
            HStack(spacing: 6) {
                ForEach(ReviewRating.allCases) { rating in
                    Button {
                        switch practiceMode {
                        case .kanji:
                            if let card = cards[safe: trainingSession.currentIndex] { applyReview(rating, to: card) }
                        case .words: applyWordReview(rating)
                        case .kana: applyKanaReview(rating)
                        case .anki: applyAnkiReview(rating)
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(rating.title).font(.caption.weight(.bold))
                            let interval = trainingSession.intervalLabel(for: rating)
                            if !interval.isEmpty { Text(interval).font(.caption2) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ratingButtonColor(for: rating, hasFeedback: true, isAnswered: true))
                    .disabled(!drawingSession.isAnswerVisible || trainingSession.isPreparingCard)
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

        switch rating {
        case .again:
            return AppPalette.correction
        case .hard:
            return AppPalette.warning
        case .good:
            return AppPalette.success
        case .easy:
            return AppPalette.accent
        }
    }

    @ViewBuilder
    func sessionAnswerLabel() -> some View {
        if let rating = currentSessionRating() {
            Label("Ответ: \(rating.title)", systemImage: rating.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ratingButtonColor(for: rating, hasFeedback: true, isAnswered: true))
        }
    }

    func feedbackInfoButton(items: [StrokeFeedback]) -> some View {
        @Bindable var session = drawingSession

        return Button {
            drawingSession.showsFeedbackInfo = true
        } label: {
            Image(systemName: "info.circle")
        }
        .popover(isPresented: $session.showsFeedbackInfo, arrowEdge: .bottom) {
            feedbackInfoPopover(items: items)
                .presentationCompactAdaptation(.popover)
        }
    }

    func feedbackInfoPopover(items: [StrokeFeedback]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Проверка")
                .font(.headline)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        Text(item.message)
                            .font(.footnote)
                            .foregroundStyle(item.severity.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(AppPalette.surface)
    }

    func drawingPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.42, 310), 355)
    }

    func drawingBoardSide(for panelHeight: CGFloat) -> CGFloat {
        min(max(panelHeight - 132, 160), 205)
    }

}
