import SwiftUI

extension ContentView {
    func displayedKanjiMeanings(for card: KanjiCard) -> [String] {
        switch meaningLanguage {
        case .russian:
            return card.cachedRussianMeanings ?? card.englishMeanings
        case .english:
            return card.englishMeanings
        }
    }

    func displayedKanjiExamples(for card: KanjiCard) -> [KanjiExample] {
        switch meaningLanguage {
        case .russian:
            return card.cachedRussianExamples ?? card.englishExamples
        case .english:
            return card.englishExamples
        }
    }

    func displayedWordMeaning(for card: WordStudyCard) -> String {
        switch meaningLanguage {
        case .russian:
            return wordMeaningTranslations[card.id] ?? RussianMeaningTranslator.translateLocally([card.meaning]).first ?? card.meaning
        case .english:
            return card.meaning
        }
    }

    func translateWordMeaningIfNeeded(for card: WordStudyCard) async {
        guard meaningLanguage == .russian, wordMeaningTranslations[card.id] == nil else {
            return
        }

        let translatedMeaning = await RussianMeaningTranslator.translate([card.meaning]).first ?? card.meaning
        await MainActor.run {
            guard meaningLanguage == .russian, wordMeaningTranslations[card.id] == nil else {
                return
            }

            wordMeaningTranslations[card.id] = translatedMeaning
            KanjiTranslationStore.saveWordTranslation(translatedMeaning, for: card.id)
        }
    }

    func retranslateWordMeaning(_ card: WordStudyCard) {
        guard meaningLanguage == .russian, !retranslationWordKeys.contains(card.id) else {
            return
        }

        retranslationWordKeys.insert(card.id)

        Task { @MainActor in
            let translatedMeaning = await RussianMeaningTranslator.translate([card.meaning]).first ?? card.meaning
            wordMeaningTranslations[card.id] = translatedMeaning
            KanjiTranslationStore.saveWordTranslation(translatedMeaning, for: card.id)
            retranslationWordKeys.remove(card.id)
        }
    }

    func translateKanjiMeaningsIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        let currentCard = latestKanjiCard(for: card)
        guard meaningLanguage == .russian, !currentCard.hasRussianMeanings else {
            return
        }

        let translatedCard = await KanjiDataLoader.translateMeaningsIfNeeded(currentCard, deck: deck)
        await MainActor.run {
            guard meaningLanguage == .russian else {
                return
            }

            replaceCard(translatedCard)
        }
    }

    func translateKanjiExamplesIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        let currentCard = latestKanjiCard(for: card)
        guard meaningLanguage == .russian, !currentCard.hasRussianExamples else {
            return
        }

        let translatedCard = await KanjiDataLoader.translateExamplesIfNeeded(currentCard, deck: deck)
        await MainActor.run {
            guard meaningLanguage == .russian else {
                return
            }

            replaceCard(translatedCard)
        }
    }

    func retranslateKanjiMeanings(_ card: KanjiCard, deck: KanjiDeck) {
        guard meaningLanguage == .russian, !retranslationKanjiMeaningKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiMeaningKeys.insert(card.kanji)

        Task { @MainActor in
            let currentCard = latestKanjiCard(for: card)
            let translatedMeaningsCard = await KanjiDataLoader.translateMeaningsIfNeeded(
                currentCard,
                deck: deck,
                force: true
            )
            replaceCard(translatedMeaningsCard)
            retranslationKanjiMeaningKeys.remove(card.kanji)
        }
    }

    func retranslateKanjiExamples(_ card: KanjiCard, deck: KanjiDeck) {
        guard meaningLanguage == .russian, !retranslationKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiExampleKeys.insert(card.kanji)

        Task { @MainActor in
            let currentCard = latestKanjiCard(for: card)
            let translatedExamplesCard = await KanjiDataLoader.translateExamplesIfNeeded(
                currentCard,
                deck: deck,
                force: true
            )
            replaceCard(translatedExamplesCard)
            retranslationKanjiExampleKeys.remove(card.kanji)
        }
    }

    @ViewBuilder
    func retranslateKanjiMeaningsButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: originalKanjiMeaningsText(for: card),
                isLoading: retranslationKanjiMeaningKeys.contains(card.kanji)
            ) {
                retranslateKanjiMeanings(card, deck: selectedDeck)
            }
        }
    }

    @ViewBuilder
    func retranslateKanjiExamplesButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: originalKanjiExamplesText(for: card),
                isLoading: retranslationKanjiExampleKeys.contains(card.kanji)
            ) {
                retranslateKanjiExamples(card, deck: selectedDeck)
            }
        }
    }

    @ViewBuilder
    func retranslateWordButton(for card: WordStudyCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: card.meaning,
                isLoading: retranslationWordKeys.contains(card.id)
            ) {
                retranslateWordMeaning(card)
            }
        }
    }

    func translationRetryControls(
        originalText: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        TranslationRetryControls(
            originalText: originalText,
            isLoading: isLoading,
            action: action
        )
    }

    func originalKanjiMeaningsText(for card: KanjiCard) -> String {
        card.englishMeanings.joined(separator: ", ")
    }

    func originalKanjiExamplesText(for card: KanjiCard) -> String {
        card.englishExamples.map { example in
            "\(example.word) - \(example.reading) - \(example.meaning)"
        }.joined(separator: "\n")
    }

    func latestKanjiCard(for card: KanjiCard) -> KanjiCard {
        var latestCard = card

        if let previewCard = previewCards.first(where: { $0.kanji == card.kanji }) {
            latestCard = latestCard.mergedForDisplay(with: previewCard)
        }

        if let trainingCard = cards.first(where: { $0.kanji == card.kanji }) {
            latestCard = latestCard.mergedForDisplay(with: trainingCard)
        }

        if let selectedPreviewCard, selectedPreviewCard.kanji == card.kanji {
            latestCard = latestCard.mergedForDisplay(with: selectedPreviewCard)
        }

        if let selectedLinkedKanjiCard, selectedLinkedKanjiCard.kanji == card.kanji {
            latestCard = latestCard.mergedForDisplay(with: selectedLinkedKanjiCard)
        }

        return latestCard
    }

    func readingsText(_ readings: [String]) -> String {
        readings.isEmpty ? "-" : readings.joined(separator: ", ")
    }

    func kunyomiText(for readings: [String]) -> AttributedString {
        guard !readings.isEmpty else {
            var empty = AttributedString("-")
            empty.foregroundColor = AppPalette.secondaryText
            return empty
        }

        var result = AttributedString()

        for (index, reading) in readings.enumerated() {
            if index > 0 {
                var separator = AttributedString(", ")
                separator.foregroundColor = AppPalette.text
                result += separator
            }

            let parts = reading.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            var kanjiReading = AttributedString(String(parts.first ?? ""))
            kanjiReading.foregroundColor = AppPalette.text
            result += kanjiReading

            if parts.count > 1 {
                var okurigana = AttributedString(String(parts[1]))
                okurigana.foregroundColor = AppPalette.mutedText
                result += okurigana
            }
        }

        return result
    }

}

struct TranslationRetryControls: View {
    let originalText: String
    let isLoading: Bool
    let action: () -> Void

    @State private var isOriginalPresented = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                Label(
                    isLoading ? "Перевожу" : "Перевести заново",
                    systemImage: isLoading ? "hourglass" : "arrow.clockwise"
                )
            }
            .disabled(isLoading)

            Button {
                isOriginalPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Показать оригинал")
            .popover(isPresented: $isOriginalPresented, arrowEdge: .bottom) {
                ScrollView {
                    Text(originalText.isEmpty ? "Оригинал пустой" : originalText)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(width: 320, alignment: .leading)
                }
                .background(AppPalette.surface)
                .presentationCompactAdaptation(.popover)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }
}
