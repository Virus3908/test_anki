import SwiftUI

extension ContentView {
    func displayedKanjiMeanings(for card: KanjiCard) -> [String] {
        translationState.displayedKanjiMeanings(for: card, language: meaningLanguage)
    }

    func displayedKanjiExamples(for card: KanjiCard) -> [KanjiExample] {
        translationState.displayedKanjiExamples(for: card, language: meaningLanguage)
    }

    func displayedWordMeaning(for card: WordStudyCard) -> String {
        translationState.displayedWordMeaning(for: card, language: meaningLanguage)
    }

    func displayedWordUsageExamples(for card: WordStudyCard) -> [WordUsageExample] {
        translationState.displayedWordUsageExamples(for: card, language: meaningLanguage)
    }

    func originalWordUsageExamples(for card: WordStudyCard) -> [WordUsageExample] {
        translationState.originalWordUsageExamples(for: card)
    }

    func readingsText(_ readings: [String]) -> String {
        readings.isEmpty ? "-" : readings.joined(separator: ", ")
    }

    func kunyomiText(for readings: [String]) -> AttributedString {
        KanjiReadingFormatter.kunyomiText(for: readings)
    }
}
