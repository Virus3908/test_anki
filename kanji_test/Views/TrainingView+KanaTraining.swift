import SwiftUI

extension TrainingView {
    func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        trainingCardShell {
            kanaCardFront(for: kanaCard)
        } back: {
            kanaCardBackContent(for: kanaCard) {
                presentCardFieldSettings(side: .back)
            } onSpeak: {
                speech.speak(kanaCard.character)
            }
        }
        .task(id: "speech-\(kanaCard.id)") {
            guard settings.speechEnabled else { return }
            speech.speak(kanaCard.character)
        }
    }

    func kanaCardFront(for kanaCard: KanaStudyCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй знак каны по памяти.",
            footerText: "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: kanaCard.reviewKey,
            speechText: kanaCard.character,
            isTextSelectable: false
        ) {
            ForEach(cardFields(for: .kana, side: .front)) { field in
                kanaCardField(field, for: kanaCard)
            }
        }
    }

}
