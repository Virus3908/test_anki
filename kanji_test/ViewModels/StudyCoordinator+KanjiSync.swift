import Foundation

extension StudyCoordinator {
    func replaceKanjiCard(_ card: KanjiCard, deckState: DeckPreviewViewModel) {
        deckState.replaceKanjiPreviewCard(card)
        deckState.replacePreviewWordCards { wordCard in
            replacingNestedKanji(card, in: wordCard)
        }
        replaceKanjiCard(card)
    }

    func latestKanjiCard(for card: KanjiCard, previewCards: [KanjiCard]) -> KanjiCard {
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

    func replaceKanjiCard(_ card: KanjiCard) {
        for index in cards.indices where cards[index].kanji == card.kanji {
            cards[index] = cards[index].mergedForDisplay(with: card)
        }

        mergeSelectedKanjiPreview(with: card)

        for index in wordCards.indices {
            wordCards[index] = replacingNestedKanji(card, in: wordCards[index])
        }

        if let selectedWordPreviewCard {
            replaceSelectedWordPreview(replacingNestedKanji(card, in: selectedWordPreviewCard))
        }

        mergeLinkedKanjiPreview(with: card)
    }

    func replacingNestedKanji(_ card: KanjiCard, in wordCard: WordStudyCard) -> WordStudyCard {
        let kanjiCards = wordCard.kanjiCards.map { existingCard in
            existingCard.kanji == card.kanji ? existingCard.mergedForDisplay(with: card) : existingCard
        }
        return WordStudyCard(
            word: wordCard.word,
            reading: wordCard.reading,
            meaning: wordCard.meaning,
            examples: wordCard.examples,
            kanjiCards: kanjiCards
        )
    }

    func mergeSelectedKanjiPreview(with card: KanjiCard) {
        guard selectedPreviewCard?.kanji == card.kanji else {
            return
        }

        selectedPreviewCard = selectedPreviewCard?.mergedForDisplay(with: card)
    }

    func mergeLinkedKanjiPreview(with card: KanjiCard) {
        guard selectedLinkedKanjiCard?.kanji == card.kanji else {
            return
        }

        selectedLinkedKanjiCard = selectedLinkedKanjiCard?.mergedForDisplay(with: card)
    }

    func replaceSelectedWordPreview(_ card: WordStudyCard) {
        selectedWordPreviewCard = card
    }
}
