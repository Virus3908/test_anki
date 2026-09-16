import SwiftUI

extension ContentView {
    func originalKanjiMeaningsText(for card: KanjiCard) -> String {
        card.englishMeanings.joined(separator: ", ")
    }

    func originalKanjiExamplesText(for card: KanjiCard) -> String {
        card.englishExamples.map { example in
            "\(example.word) - \(example.reading) - \(example.meaning)"
        }.joined(separator: "\n")
    }

    func originalWordExamplesText(for card: WordStudyCard) -> String {
        originalWordUsageExamples(for: card).map { example in
            [
                example.sentence,
                wordExampleReading(for: example, card: card),
                example.meaning
            ]
            .compactMap { text in
                guard let text, !text.isEmpty else {
                    return nil
                }

                return text
            }
            .joined(separator: " - ")
        }.joined(separator: "\n")
    }
}
