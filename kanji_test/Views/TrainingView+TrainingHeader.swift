import SwiftUI

extension TrainingView {
    func cardSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                guard trainingSession.isGuidedSingleKanjiPractice else { return }
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.4, abs(width) > 70 else {
                    return
                }

                if width < 0 {
                    moveToNextCard()
                } else {
                    moveToPreviousCard()
                }
            }
    }

    func headerControls() -> some View {
        TrainingHeaderView(
            title: trainingTitle,
            isPractice: trainingSession.isGuidedSingleKanjiPractice,
            completedCards: trainingSession.sessionCompletedCards,
            remainingCards: trainingSession.sessionTotalCards,
            onFinish: finishTraining,
            onExclude: excludeCurrentCard
        )
    }

}

private struct TrainingHeaderView: View {
    let title: String
    let isPractice: Bool
    let completedCards: Int
    let remainingCards: Int
    let onFinish: () -> Void
    let onExclude: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Button {
                    onFinish()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 34, height: 30)
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !isPractice {
                    Button {
                        onExclude()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Исключить карточку из тренировок")
                }
            }

            Text(isPractice ? "Практика" : "Ответов: \(completedCards) · Осталось: \(remainingCards)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

}
