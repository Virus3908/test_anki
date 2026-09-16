import Foundation

extension KanjiDataLoader {
    static func translateMeaningsIfNeeded(
        _ card: KanjiCard,
        deck: KanjiDeck,
        force: Bool = false,
        translator: MeaningTranslating = SystemRussianMeaningTranslator()
    ) async -> KanjiCard {
        guard force || !card.hasRussianMeanings else {
            return card
        }

        let meanings = await translator.translate(card.englishMeanings)
        let translatedCard = card.withRussianMeanings(meanings)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    static func translateExamplesIfNeeded(
        _ card: KanjiCard,
        deck: KanjiDeck,
        force: Bool = false,
        translator: MeaningTranslating = SystemRussianMeaningTranslator()
    ) async -> KanjiCard {
        guard force || !card.hasRussianExamples else {
            return card
        }

        let sourceExamples = card.englishExamples
        let translatedExampleMeanings = await translator.translatePreservingOrder(sourceExamples.map(\.meaning))
        let examples = sourceExamples.enumerated().map { index, example in
            KanjiExample(
                word: example.word,
                reading: example.reading,
                meaning: index < translatedExampleMeanings.count ? translatedExampleMeanings[index] : example.meaning
            )
        }
        let translatedCard = card.withRussianExamples(examples)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    static func cacheTranslatedCard(_ card: KanjiCard, deck: KanjiDeck) {
        TranslationRepository.saveKanjiTranslation(from: card)
    }
}
