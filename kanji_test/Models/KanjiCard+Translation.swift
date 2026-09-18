import Foundation

nonisolated extension KanjiCard {
    var englishMeanings: [String] {
        sourceMeanings ?? meanings
    }

    var englishExamples: [KanjiExample] {
        sourceExamples ?? examples
    }

    func withEnglishExamples(_ examples: [KanjiExample]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: englishMeanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: examples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: nil,
            russianExamples: nil,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: nil
        )
    }

    func mergedForDisplay(with updatedCard: KanjiCard) -> KanjiCard {
        updatedCard.withoutTranslations
    }

    var withoutTranslations: KanjiCard {
        withEnglishExamples(englishExamples)
    }
}
