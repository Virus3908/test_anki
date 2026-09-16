import SwiftUI

extension ContentView {
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
        ForEach(frontFieldOrder) { field in
            switch field {
            case .readings:
                wordReadingField(for: wordCard)
            case .meanings:
                wordMeaningField(for: wordCard)
            case .character:
                wordCharacterField(for: wordCard)
            }
        }
    }

    @ViewBuilder
    func wordCharacterField(for wordCard: WordStudyCard) -> some View {
        if trainingSession.isAnswerVisible || showsPromptCharacters {
            detailBlock("Слово") {
                Text(wordCard.word)
                    .font(.system(size: 42, weight: .regular, design: .serif))
            }
        }
    }

    @ViewBuilder
    func wordReadingField(for wordCard: WordStudyCard) -> some View {
        if trainingSession.isAnswerVisible || showsPromptReading {
            detailBlock("Чтение") {
                Text(wordCard.reading)
            }
        }
    }

    @ViewBuilder
    func wordMeaningField(for wordCard: WordStudyCard) -> some View {
        if trainingSession.isAnswerVisible || showsPromptMeaning {
            translatableTextBlock("Значения", text: displayedWordMeaning(for: wordCard)) {
                retranslateWordButton(for: wordCard)
            }
        }
    }

    func completedWordStrip(for wordCard: WordStudyCard) -> some View {
        HStack(spacing: 8) {
            ForEach(wordCard.kanjiCards.indices, id: \.self) { index in
                let isSelected = index == trainingSession.currentWordKanjiIndex
                ZStack {
                    if isSelected && !trainingSession.drawnStrokes.isEmpty {
                        UserStrokePreview(strokes: trainingSession.drawnStrokes)
                    } else if index < trainingSession.completedWordDrawings.count {
                        UserStrokePreview(strokes: trainingSession.completedWordDrawings[index])
                    } else if trainingSession.isAnswerVisible || showsPromptCharacters {
                        Text(wordCard.kanjiCards[index].kanji)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(trainingSession.isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index == trainingSession.currentWordKanjiIndex ? AppPalette.accent : AppPalette.mutedText)
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
        wordCard.kanjiCards[safe: trainingSession.currentWordKanjiIndex]
    }

}
