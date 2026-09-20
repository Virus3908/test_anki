import SwiftUI

extension TrainingView {
    func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        trainingCardShell {
            kanaCardFront(for: kanaCard)
        } back: {
            kanaCardBackContent(for: kanaCard)
        }
    }

    func kanaCardFront(for kanaCard: KanaStudyCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй знак каны по памяти.",
            footerText: "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: kanaCard.reviewKey,
            isTextSelectable: false
        ) {
            ForEach(cardFields(for: .kana, side: .front)) { field in
                kanaCardField(field, for: kanaCard)
            }
        }
    }

}
