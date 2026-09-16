import Foundation

extension TranslationViewModel {
    func displayedKanjiMeanings(for card: KanjiCard, language: MeaningLanguage) -> [String] {
        switch language {
        case .russian:
            return card.cachedRussianMeanings ?? card.englishMeanings
        case .english:
            return card.englishMeanings
        }
    }

    func displayedKanjiExamples(for card: KanjiCard, language: MeaningLanguage) -> [KanjiExample] {
        switch language {
        case .russian:
            return card.cachedRussianExamples ?? card.englishExamples
        case .english:
            return card.englishExamples
        }
    }

    func translateKanjiMeaningsIfNeeded(
        for card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) async -> KanjiCard? {
        guard language == .russian, !card.hasRussianMeanings else {
            return nil
        }

        return await KanjiDataLoader.translateMeaningsIfNeeded(card, deck: deck)
    }

    func translateKanjiExamplesIfNeeded(
        for card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) async -> KanjiCard? {
        guard language == .russian, !card.hasRussianExamples else {
            return nil
        }

        return await KanjiDataLoader.translateExamplesIfNeeded(card, deck: deck)
    }

    func retranslateKanjiMeanings(
        _ card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage,
        onTranslated: @MainActor @escaping (KanjiCard) -> Void
    ) {
        guard language == .russian, !retranslationKanjiMeaningKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiMeaningKeys.insert(card.kanji)

        Task { @MainActor in
            let translatedCard = await KanjiDataLoader.translateMeaningsIfNeeded(
                card,
                deck: deck,
                force: true
            )
            onTranslated(translatedCard)
            retranslationKanjiMeaningKeys.remove(card.kanji)
        }
    }

    func retranslateKanjiExamples(
        _ card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage,
        onTranslated: @MainActor @escaping (KanjiCard) -> Void
    ) {
        guard language == .russian, !retranslationKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiExampleKeys.insert(card.kanji)

        Task { @MainActor in
            let translatedCard = await KanjiDataLoader.translateExamplesIfNeeded(
                card,
                deck: deck,
                force: true
            )
            onTranslated(translatedCard)
            retranslationKanjiExampleKeys.remove(card.kanji)
        }
    }
}
