import SwiftUI

extension TrainingView {
    func wordStudyCard(for wordCard: WordStudyCard) -> some View {
        trainingCardShell {
            wordCardFront(for: wordCard)
        } back: {
            studyCardBackShell(reviewKey: wordCard.reviewKey) {
                wordFullCardContent(for: wordCard)
            }
        }
        .task(id: "\(wordCard.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: wordCard)
        }
    }

    func wordCardFront(for wordCard: WordStudyCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй символы слова по памяти.",
            footerText: "Проверка покажет слово, чтение, перевод и состав.",
            reviewKey: wordCard.reviewKey
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
        HStack(spacing: 8) {
            ForEach(wordCard.kanjiCards.enumerated(), id: \.offset) { index, kanjiCard in
                let isSelected = index == drawingSession.currentWordKanjiIndex
                ZStack {
                    if isSelected && !drawingSession.drawnStrokes.isEmpty {
                        UserStrokePreview(strokes: drawingSession.drawnStrokes)
                    } else if index < drawingSession.completedWordDrawings.count {
                        UserStrokePreview(strokes: drawingSession.completedWordDrawings[index])
                    } else if drawingSession.isAnswerVisible || cardFields(for: .words, side: .front).contains(.word) {
                        Text(kanjiCard.kanji)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(drawingSession.isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index == drawingSession.currentWordKanjiIndex ? AppPalette.accent : AppPalette.mutedText)
                    }
                }
                .frame(width: 34, height: 34)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppPalette.accent : AppPalette.border.opacity(0.45), lineWidth: isSelected ? 2 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectWordKanji(at: index, in: wordCard)
                }
            }
        }
    }

    func currentWordKanjiCard(for wordCard: WordStudyCard) -> KanjiCard? {
        wordCard.kanjiCards[safe: drawingSession.currentWordKanjiIndex]
    }

}
