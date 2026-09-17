import Foundation

extension CardContentRendering {
    func translateWordMeaningIfNeeded(for card: WordStudyCard) async {
        await translationState.translateWordMeaningIfNeeded(for: card, language: meaningLanguage)
    }

    func retranslateWordMeaning(_ card: WordStudyCard) {
        translationState.retranslateWordMeaning(card, language: meaningLanguage)
    }

    func retranslateWordExamples(_ card: WordStudyCard) {
        translationState.retranslateWordExamples(card, language: meaningLanguage)
    }

    func translateKanjiMeaningsIfNeeded(for card: KanjiCard, deck: KanjiDeck) async {
        let currentCard = coordinator.latestKanjiCard(for: card)
        await translationState.translateKanjiMeaningsIfNeeded(
            for: currentCard,
            deck: deck,
            language: meaningLanguage
        )
    }

    func loadKanjiExamplesIfNeeded(for card: KanjiCard) async {
        let currentCard = coordinator.latestKanjiCard(for: card)
        await translationState.loadKanjiExamplesIfNeeded(for: currentCard, language: meaningLanguage)
    }

    func retranslateKanjiMeanings(_ card: KanjiCard, deck: KanjiDeck) {
        let currentCard = coordinator.latestKanjiCard(for: card)
        translationState.retranslateKanjiMeanings(currentCard, deck: deck, language: meaningLanguage)
    }

    func retranslateKanjiExamples(_ card: KanjiCard, deck: KanjiDeck) {
        let currentCard = coordinator.latestKanjiCard(for: card)
        translationState.retranslateKanjiExamples(currentCard, language: meaningLanguage)
    }

    func reloadKanjiExamples(_ card: KanjiCard) {
        let currentCard = coordinator.latestKanjiCard(for: card)
        translationState.reloadKanjiExamples(currentCard, language: meaningLanguage)
    }
}
