import SwiftUI

extension CardContentRendering {
    func cardBackContent(
        for card: KanjiCard,
        fields: [BuiltInCardField]? = nil,
        onShowAllFields: (() -> Void)? = nil,
        onSpeak: (() -> Void)? = nil
    ) -> some View {
        studyCardBackShell(reviewKey: card.reviewKey, onShowAllFields: onShowAllFields, onSpeak: onSpeak) {
            kanjiCardFields(fields ?? cardFields(for: .kanji, side: .back), for: card)
        }
    }

    @ViewBuilder
    func kanjiCardFields(_ fields: [BuiltInCardField], for card: KanjiCard) -> some View {
        let showsCharacter = fields.contains(.character)
        let showsStrokeOrder = fields.contains(.strokeOrder) && !card.strokes.isEmpty
        let combinedField = fields.first { $0 == .character || $0 == .strokeOrder }

        ForEach(fields) { field in
            if showsCharacter && showsStrokeOrder && field == combinedField {
                HStack(alignment: .top, spacing: 16) {
                    kanjiCardField(.character, for: card)
                        .frame(width: 82, alignment: .topLeading)

                    kanjiCardField(.strokeOrder, for: card)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if field != .character && field != .strokeOrder {
                kanjiCardField(field, for: card)
            } else if !showsCharacter || !showsStrokeOrder {
                kanjiCardField(field, for: card)
            }
        }
    }

    @ViewBuilder
    func kanjiCardField(_ field: BuiltInCardField, for card: KanjiCard) -> some View {
        switch field {
        case .character:
            detailBlock("Кандзи") {
                Text(card.kanji)
                    .font(.system(size: 58, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
            }
        case .onyomi:
            detailBlock("Онъёми") {
                Text(readingsText(card.onyomi)).foregroundStyle(AppPalette.text)
            }
        case .kunyomi:
            detailBlock("Кунъёми") {
                Text(kunyomiText(for: card.kunyomi)).foregroundStyle(AppPalette.text)
            }
        case .meanings:
            translatableTextBlock("Значения", text: displayedKanjiMeanings(for: card).joined(separator: ", ")) {
                retranslateKanjiMeaningsButton(for: card)
            }
            .task(id: "kanji-meaning-\(card.id)-\(meaningLanguage.rawValue)") {
                await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
            }
        case .strokeOrder:
            if !card.strokes.isEmpty {
                detailBlock("Порядок черт") {
                    StrokeStepStrip(strokes: card.strokes, spacing: 0)
                }
            }
        case .relatedWords:
            kanjiRelatedWordsBlock(for: card)
        case .examples:
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
        default:
            EmptyView()
        }
    }
}
