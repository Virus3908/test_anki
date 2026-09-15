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
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            frontFields(for: card)

            if !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text("Нарисуй кандзи по памяти.")
                    .font(.title2.weight(.semibold))
            }

            Spacer(minLength: 16)

            Text("Проверка покажет оригинал и сравнение штрихов.")
                .foregroundStyle(AppPalette.secondaryText)

            learningStatusLabel(forReviewKey: reviewKey(for: card))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
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
            detailBlock("Значения") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedKanjiMeanings(for: card).joined(separator: ", "))
                        .fixedSize(horizontal: false, vertical: true)

                    retranslateKanjiMeaningsButton(for: card)
                }
            }
            .task(id: "front-meaning-\(card.id)-\(meaningLanguage.rawValue)") {
                await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
            }
        }
    }

    func cardBackContent(for card: KanjiCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Text(card.kanji)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .frame(width: 112, height: 112)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))

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

                    detailBlock("Значения") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(displayedKanjiMeanings(for: card).joined(separator: ", "))
                                .foregroundStyle(AppPalette.text)

                            retranslateKanjiMeaningsButton(for: card)
                        }
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

            learningStatusLabel(forReviewKey: reviewKey(for: card))
        }
        .textSelection(.enabled)
    }

}
