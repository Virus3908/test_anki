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
            ForEach(frontFieldOrder) { field in
                if field == .readings && showsPromptReading {
                    detailBlock("Чтение") {
                        Text(kanaCard.reading).font(.largeTitle.weight(.bold))
                    }
                } else if field == .character && showsPromptCharacters {
                    detailBlock("Знак") {
                        Text(kanaCard.character).font(.system(size: 58, design: .serif))
                    }
                }
            }
        }
    }

}
