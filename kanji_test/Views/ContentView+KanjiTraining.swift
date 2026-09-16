import SwiftUI

extension ContentView {
    func studyCard(for card: KanjiCard) -> some View {
        trainingCardShell {
            cardFront(for: card)
        } back: {
            cardBackContent(for: card)
        }
        .task(id: "back-\(card.id)-\(meaningLanguage.rawValue)") {
            await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
            await translateKanjiExamplesIfNeeded(for: card, deck: selectedDeck)
        }
    }

    func cardFront(for card: KanjiCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй кандзи по памяти.",
            footerText: "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: card.reviewKey
        ) {
            frontFields(for: card)
        }
    }

    @ViewBuilder
    func frontFields(for card: KanjiCard) -> some View {
        ForEach(frontFieldOrder) { field in
            switch field {
            case .readings:
                frontReadings(for: card)
            case .meanings:
                frontMeanings(for: card)
            case .character:
                frontCharacter(for: card)
            }
        }
    }

    @ViewBuilder
    func frontCharacter(for card: KanjiCard) -> some View {
        if showsPromptCharacters {
            detailBlock("Кандзи") {
                Text(card.kanji)
                    .font(.system(size: 58, weight: .regular, design: .serif))
            }
        }
    }

    @ViewBuilder
    func frontReadings(for card: KanjiCard) -> some View {
        if showsPromptReading {
            detailBlock("Онъёми") {
                Text(readingsText(card.onyomi))
            }

            detailBlock("Кунъёми") {
                Text(kunyomiText(for: card.kunyomi))
            }
        }
    }

    @ViewBuilder
    func frontMeanings(for card: KanjiCard) -> some View {
        if showsPromptMeaning {
            translatableTextBlock("Значения", text: displayedKanjiMeanings(for: card).joined(separator: ", ")) {
                retranslateKanjiMeaningsButton(for: card)
            }
            .task(id: "front-meaning-\(card.id)-\(meaningLanguage.rawValue)") {
                await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
            }
        }
    }

    func cardBackContent(for card: KanjiCard) -> some View {
        studyCardBackShell(reviewKey: card.reviewKey) {
            HStack(alignment: .top, spacing: 10) {
                largeCharacterPanel(card.kanji)

                detailBlock("Порядок черт") {
                    StrokeStepStrip(strokes: card.strokes, spacing: 0)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    detailBlock("Кандзи") {
                        Text(card.kanji)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Онъёми") {
                        Text(readingsText(card.onyomi))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Кунъёми") {
                        Text(kunyomiText(for: card.kunyomi))
                            .foregroundStyle(AppPalette.text)
                    }

                    translatableTextBlock("Значения", text: displayedKanjiMeanings(for: card).joined(separator: ", ")) {
                        retranslateKanjiMeaningsButton(for: card)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            let examples = displayedKanjiExamples(for: card)
            if !examples.isEmpty {
                section("Примеры") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(examples) { example in
                            Text("\(example.word) - \(example.reading) - \(example.meaning)")
                                .foregroundStyle(AppPalette.text)
                        }

                        retranslateKanjiExamplesButton(for: card)
                    }
                }
            }
        }
    }

}
