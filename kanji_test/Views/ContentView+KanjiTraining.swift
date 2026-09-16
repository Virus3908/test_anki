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

            section("Примеры") {
                VStack(alignment: .leading, spacing: 8) {
                    let examples = displayedKanjiExamples(for: card)
                    if examples.isEmpty {
                        if translationState.translationKanjiExampleKeys.contains(card.kanji)
                            || translationState.retranslationKanjiExampleKeys.contains(card.kanji)
                            || translationState.reloadingKanjiExampleKeys.contains(card.kanji) {
                            ProgressView(translationState.reloadingKanjiExampleKeys.contains(card.kanji) ? "Запрашиваю примеры" : "Загружаю примеры")
                                .font(.caption)
                                .foregroundStyle(AppPalette.secondaryText)
                                .tint(AppPalette.accent)
                        } else {
                            Text("Примеры пока не загружены")
                                .font(.caption)
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                    } else {
                        ForEach(examples) { example in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(example.word)
                                    .foregroundStyle(AppPalette.text)

                                let details = [example.reading, example.meaning]
                                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                    .joined(separator: " - ")
                                if !details.isEmpty {
                                    Text(details)
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.secondaryText)
                                }
                            }
                        }
                    }

                    retranslateKanjiExamplesButton(for: card)
                    reloadKanjiExamplesButton(for: card)
                }
                .task(id: "kanji-examples-\(card.id)-\(meaningLanguage.rawValue)") {
                    await loadKanjiExamplesIfNeeded(for: card)
                }
            }
        }
    }

}
