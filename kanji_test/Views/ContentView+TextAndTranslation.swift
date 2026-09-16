import Foundation

extension ContentView {
    func translateWordMeaningIfNeeded(for card: WordStudyCard) async {
        await translationState.translateWordMeaningIfNeeded(for: card, language: meaningLanguage)
    }

    func retranslateWordMeaning(_ card: WordStudyCard) {
        translationState.retranslateWordMeaning(card, language: meaningLanguage)
    }

    func translateWordExamplesIfNeeded(for card: WordStudyCard, examples: [WordUsageExample]) async {
        await translationState.translateWordExamplesIfNeeded(for: card, examples: examples, language: meaningLanguage)
    }

    func retranslateWordExamples(_ card: WordStudyCard) {
        translationState.retranslateWordExamples(card, language: meaningLanguage)
    }

    func translateKanjiMeaningsIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        let currentCard = coordinator.latestKanjiCard(for: card, previewCards: deckState.previewCards)
        if let translatedCard = await translationState.translateKanjiMeaningsIfNeeded(
            for: currentCard,
            deck: deck,
            language: meaningLanguage
        ) {
            replaceCard(translatedCard)
        }
    }

    func translateKanjiExamplesIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        let currentCard = coordinator.latestKanjiCard(for: card, previewCards: deckState.previewCards)
        if let translatedCard = await translationState.translateKanjiExamplesIfNeeded(
            for: currentCard,
            deck: deck,
            language: meaningLanguage
        ) {
            replaceCard(translatedCard)
        }
    }

    func retranslateKanjiMeanings(_ card: KanjiCard, deck: KanjiDeck) {
        let currentCard = coordinator.latestKanjiCard(for: card, previewCards: deckState.previewCards)
        translationState.retranslateKanjiMeanings(currentCard, deck: deck, language: meaningLanguage) { translatedCard in
            replaceCard(translatedCard)
        }
    }

    func retranslateKanjiExamples(_ card: KanjiCard, deck: KanjiDeck) {
        let currentCard = coordinator.latestKanjiCard(for: card, previewCards: deckState.previewCards)
        translationState.retranslateKanjiExamples(currentCard, deck: deck, language: meaningLanguage) { translatedCard in
            replaceCard(translatedCard)
        }
    }
}
