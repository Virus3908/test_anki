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
        let isPractice = trainingSession.isGuidedSingleKanjiPractice
        let subtitle = isPractice
            ? "Практика"
            : "Ответов: \(trainingSession.sessionCompletedCards) · Осталось: \(trainingSession.sessionTotalCards)"

        return TrainingHeaderView(
            title: trainingTitle,
            subtitle: subtitle,
            onFinish: { finishTraining() },
            onExclude: isPractice ? nil : { excludeCurrentCard() }
        )
    }

}
