import SwiftUI

extension TrainingView {
    func reviewButton(_ title: String, rating: ReviewRating, card: KanjiCard) -> some View {
        ratingActionButton(
            title,
            color: ratingButtonColor(for: rating, hasFeedback: !drawingSession.feedback.isEmpty, isAnswered: currentSessionRating() != nil),
            isSelected: sessionRating(at: trainingSession.currentIndex) == rating
        ) {
            applyReview(rating, to: card)
        }
        .disabled(trainingSession.isPreparingCard)
    }

    func ratingActionButton(
        _ title: String,
        color: Color,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppPalette.text.opacity(0.75) : Color.clear, lineWidth: 2)
        )
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
        min(max(size.height * 0.36, 250), 300)
    }

    func drawingBoardSide(for panelHeight: CGFloat) -> CGFloat {
        min(max(panelHeight - 88, 160), 205)
    }

}
