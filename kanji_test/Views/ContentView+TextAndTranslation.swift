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
        }
    }

    func translateKanjiMeaningsIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        guard meaningLanguage == .russian, !card.hasRussianMeanings else {
            return
        }

        let translatedCard = await KanjiDataLoader.translateMeaningsIfNeeded(card, deck: deck)
        await MainActor.run {
            guard meaningLanguage == .russian else {
                return
            }

            replaceCard(translatedCard)
        }
    }

    func translateKanjiExamplesIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        guard meaningLanguage == .russian, !card.hasRussianExamples else {
            return
        }

        let translatedCard = await KanjiDataLoader.translateExamplesIfNeeded(card, deck: deck)
        await MainActor.run {
            guard meaningLanguage == .russian else {
                return
            }

            replaceCard(translatedCard)
        }
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
