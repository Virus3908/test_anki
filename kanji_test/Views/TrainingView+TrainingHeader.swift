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
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Button {
                    finishTraining()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 34, height: 30)
                }

                Text(trainingTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !trainingSession.isGuidedSingleKanjiPractice {
                    Button {
                        excludeCurrentCard()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Исключить карточку из тренировок")
                }
            }

            Text(trainingSession.isGuidedSingleKanjiPractice ? "Практика" : "Ответов: \(trainingSession.sessionCompletedCards) · Осталось: \(trainingSession.sessionTotalCards)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

}
