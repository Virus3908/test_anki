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
        HStack(spacing: 12) {
            Button {
                finishTraining()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 34, height: 30)
            }

            Text(trainingTitle)
                .font(.headline)

            Spacer()

            Text(trainingSession.isGuidedSingleKanjiPractice ? "Практика" : "Ответов: \(trainingSession.sessionCompletedCards) · Осталось: \(trainingSession.sessionTotalCards)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

}
