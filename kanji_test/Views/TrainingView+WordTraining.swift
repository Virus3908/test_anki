import SwiftUI

extension TrainingView {
    func wordStudyCard(for wordCard: WordStudyCard) -> some View {
        trainingCardShell {
            wordCardFront(for: wordCard)
        } back: {
            studyCardBackShell(
                reviewKey: wordCard.reviewKey,
                onShowAllFields: { presentCardFieldSettings(side: .back) },
                onSpeak: { speech.speak(wordCard.word) }
            ) {
                wordFullCardContent(for: wordCard)
            }
        }
        .task(id: "\(wordCard.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: wordCard)
        }
        .task(id: "speech-\(wordCard.id)") {
            guard settings.speechEnabled else { return }
            speech.speak(wordCard.word)
        }
    }

    func wordCardFront(for wordCard: WordStudyCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй символы слова по памяти.",
            footerText: "Проверка покажет слово, чтение, перевод и состав.",
            reviewKey: wordCard.reviewKey,
            speechText: wordCard.word
        ) {
            wordFrontFields(for: wordCard)
        }
    }

    @ViewBuilder
    func wordFrontFields(for wordCard: WordStudyCard) -> some View {
        ForEach(cardFields(for: .words, side: .front)) { field in
            wordCardField(field, for: wordCard)
        }
    }

    func completedWordStrip(for wordCard: WordStudyCard) -> some View {
        CompletedWordStrip(
            wordCard: wordCard,
            currentKanjiIndex: drawingSession.currentWordKanjiIndex,
            drawnStrokes: drawingSession.drawnStrokes,
            completedDrawings: drawingSession.completedWordDrawings,
            isAnswerVisible: drawingSession.isAnswerVisible,
            isKanjiTextShown: cardFields(for: .words, side: .front).contains(.word),
            onSelectKanji: { selectWordKanji(at: $0, in: wordCard) }
        )
    }

    func currentWordKanjiCard(for wordCard: WordStudyCard) -> KanjiCard? {
        wordCard.kanjiCards[safe: drawingSession.currentWordKanjiIndex]
    }

}
