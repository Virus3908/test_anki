import SwiftUI

extension CardContentRendering {
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

            detailBlock("Примеры") {
                let key = TranslationBlockKey.kanjiExamples(card.kanji)
                StudyExamplesContent(
                    examples: displayedKanjiExamples(for: card).map { StudyExample(kanjiExample: $0) },
                    isLoading: translationState.isAutomaticallyTranslating(key)
                        || translationState.isManuallyTranslating(key)
                        || translationState.isManuallyReloadingExamples(key),
                    loadingText: translationState.isManuallyReloadingExamples(key)
                        ? "Запрашиваю примеры"
                        : "Загружаю примеры",
                    emptyText: "Примеры пока не загружены"
                ) {
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
