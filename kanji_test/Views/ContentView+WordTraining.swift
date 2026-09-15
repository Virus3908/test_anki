import SwiftUI

extension ContentView {
    func wordStudyCard(for wordCard: WordStudyCard) -> some View {
        ZStack {
            wordCardFront(for: wordCard)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            ScrollView {
                wordFullCardContent(for: wordCard)
            }
            .opacity(isAnswerVisible ? 1 : 0)
            .rotation3DEffect(.degrees(isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .appSurfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .gesture(cardSwipeGesture())
        .task(id: "\(wordCard.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: wordCard)
        }
    }

    func wordCardFront(for wordCard: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            wordFrontFields(for: wordCard)

            if !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text("Нарисуй символы слова по памяти.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
            }

            Spacer(minLength: 16)

            Text("Проверка покажет слово, чтение, перевод и состав.")
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        if isAnswerVisible || showsPromptCharacters {
            detailBlock("Слово") {
                Text(wordCard.word)
                    .font(.system(size: 42, weight: .regular, design: .serif))
            }
        }
    }

    @ViewBuilder
    func wordReadingField(for wordCard: WordStudyCard) -> some View {
        if isAnswerVisible || showsPromptReading {
            detailBlock("Чтение") {
                Text(wordCard.reading)
            }
        }
    }

    @ViewBuilder
    func wordMeaningField(for wordCard: WordStudyCard) -> some View {
        if isAnswerVisible || showsPromptMeaning {
            detailBlock("Значения") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedWordMeaning(for: wordCard))
                        .fixedSize(horizontal: false, vertical: true)

                    retranslateWordButton(for: wordCard)
                }
            }
        }
    }

    func completedWordStrip(for wordCard: WordStudyCard) -> some View {
        HStack(spacing: 8) {
            ForEach(wordCard.kanjiCards.indices, id: \.self) { index in
                let isSelected = index == currentWordKanjiIndex
                ZStack {
                    if isSelected && !drawnStrokes.isEmpty {
                        UserStrokePreview(strokes: drawnStrokes)
                    } else if index < completedWordDrawings.count {
                        UserStrokePreview(strokes: completedWordDrawings[index])
                    } else if isAnswerVisible || showsPromptCharacters {
                        Text(wordCard.kanjiCards[index].kanji)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index == currentWordKanjiIndex ? AppPalette.accent : AppPalette.mutedText)
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
        wordCard.kanjiCards[safe: currentWordKanjiIndex]
    }

}
