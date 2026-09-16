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
        let cardWithExamples = await loadExamplesIfNeeded(card)
        guard force || !cardWithExamples.hasRussianExamples else {
            return cardWithExamples
        }

        let sourceExamples = cardWithExamples.englishExamples
        let translatedExampleMeanings = await translator.translatePreservingOrder(sourceExamples.map(\.meaning))
        let examples = sourceExamples.enumerated().map { index, example in
            KanjiExample(
                word: example.word,
                reading: example.reading,
                meaning: index < translatedExampleMeanings.count ? translatedExampleMeanings[index] : example.meaning
            )
        }
        let translatedCard = cardWithExamples.withRussianExamples(examples)
        cacheTranslatedCard(translatedCard, deck: deck)
        return translatedCard
    }

    static func loadExamplesIfNeeded(
        _ card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        guard card.englishExamples.isEmpty else {
            return card
        }

        if let cachedExamples = KanjiExampleCacheRepository.loadExamples(for: card.kanji) {
            return card.withEnglishExamples(cachedExamples)
        }

        let remoteExamples = await provider.loadExamples(for: card.kanji)
        if !remoteExamples.isEmpty {
            KanjiExampleCacheRepository.saveExamples(remoteExamples, for: card.kanji)
        }
        return card.withEnglishExamples(remoteExamples)
    }

    static func reloadExamples(
        for card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        let remoteExamples = await provider.loadExamples(for: card.kanji)
        if !remoteExamples.isEmpty {
            KanjiExampleCacheRepository.saveExamples(remoteExamples, for: card.kanji)
        }
        return card.withEnglishExamples(remoteExamples)
    }

    static func cacheTranslatedCard(_ card: KanjiCard, deck: KanjiDeck) {
        TranslationRepository.saveKanjiTranslation(from: card)
    }
}
