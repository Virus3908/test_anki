import SwiftUI

extension ContentView {
    func resetSessionProgress(total: Int) {
        trainingSession.resetSessionProgress(total: total)
    }

    func resetWordDrawingState(resetKanjiIndex: Bool = true) {
        trainingSession.resetWordDrawingState(resetKanjiIndex: resetKanjiIndex)
    }

    func prepareStudyPack<Item: StudyItem>(
        _ items: [Item],
        guided: Bool? = nil,
        scrollToTop: Bool = false
    ) {
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: TrainingSessionEngine.uniqueReviewItemCount(items))
        if let guided {
            trainingSession.isGuidedSingleKanjiPractice = guided
        }
        trainingSession.isPreparingCard = false
        resetCurrentAnswer()
        if scrollToTop {
            trainingSession.scrollToTopToken += 1
        }
    }

    func openKanjiPreviewCard(_ card: KanjiCard) {
        coordinator.openKanjiPreviewCard(card)
    }

    func openKanaPreviewCard(_ card: KanaStudyCard) {
        coordinator.openKanaPreviewCard(card)
    }

    func openWordPreviewCard(_ card: WordStudyCard) {
        coordinator.openWordPreviewCard(card)
    }

    func clearDeckCache() {
        deckState.deckPreviewTask?.cancel()
        deckState.deckPreviewTask = nil
        KanjiDataLoader.clearCache()
        KanaDataLoader.clearCache()
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        deckState.kanjiSourceCards.removeAll()
        deckState.wordSourceCards.removeAll()
        deckState.kanaSourceCards.removeAll()
        deckState.previewCards.removeAll()
        deckState.previewKanaCards.removeAll()
        deckState.previewWordCards.removeAll()
        deckState.previewExpectedCount = nil
        deckState.previewDeck = nil
        deckState.previewKanaDeck = nil
        deckState.previewWordDeck = nil
        coordinator.resetPreviewSelection()
        trainingSession.resetQueuePosition()
        trainingSession.kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        resetCurrentAnswer()
    }

    func openDeckPreview(_ deck: KanjiDeck) {
        deckState.deckPreviewTask?.cancel()
        deckState.previewDeck = deck
        deckState.previewKanaDeck = nil
        deckState.previewWordDeck = nil
        deckState.previewWordCards.removeAll()
        deckState.previewKanaCards.removeAll()
        coordinator.clearDeckSelection()
        deckState.previewCards.removeAll()
        deckState.previewExpectedCount = nil
        deckState.isLoadingDeck = true

        deckState.deckPreviewTask = Task {
            await KanjiDataLoader.loadCardsProgressively(deck: deck) { loadedCards, expectedCount in
                guard deckState.previewDeck == deck else {
                    return
                }

                deckState.previewCards = reviewStore.orderedCards(loadedCards)
                deckState.previewExpectedCount = expectedCount
                deckState.isLoadingDeck = deckState.previewExpectedCount.map { deckState.previewCards.count < $0 } ?? false
            }

            if deckState.previewDeck == deck {
                deckState.isLoadingDeck = false
            }
        }
    }

    func closeDeckPreview() {
        deckState.deckPreviewTask?.cancel()
        deckState.deckPreviewTask = nil
        deckState.previewDeck = nil
        deckState.previewCards.removeAll()
        deckState.previewExpectedCount = nil
        coordinator.closeKanjiPreview()
        deckState.isLoadingDeck = false
        coordinator.closeDeckSchedule()
    }

    func openKanaPreview(_ deck: KanaDeck) {
        selectedKanaDeck = deck
        deckState.previewKanaDeck = deck
        deckState.previewDeck = nil
        deckState.previewWordDeck = nil
        deckState.previewWordCards.removeAll()
        deckState.previewKanaCards = deck.baseCards
        coordinator.clearDeckSelection()
        deckState.isLoadingDeck = true
        resetCurrentAnswer()

        Task {
            let loadedCards = await KanaDataLoader.loadCards(deck: deck)
            await MainActor.run {
                guard deckState.previewKanaDeck == deck else {
                    return
                }

                deckState.previewKanaCards = loadedCards
                deckState.isLoadingDeck = false
            }
        }
    }

    func closeKanaPreview() {
        deckState.previewKanaDeck = nil
        deckState.previewKanaCards.removeAll()
        coordinator.closeKanaPreview()
        deckState.isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startRandomTrainingFromPreview() {
        startTraining(with: nextKanjiSessionCards(from: deckState.previewCards), sourceCards: deckState.previewCards, guided: false)
    }

    func startTraining(with trainingCards: [KanjiCard], sourceCards: [KanjiCard]? = nil, guided: Bool) {
        guard !trainingCards.isEmpty else {
            return
        }

        deckState.deckPreviewTask?.cancel()
        deckState.kanjiSourceCards = sourceCards ?? trainingCards
        cards = trainingCards
        wordCards.removeAll()
        kanaCards.removeAll()
        deckState.wordSourceCards.removeAll()
        deckState.kanaSourceCards.removeAll()
        prepareStudyPack(cards, guided: guided)
        coordinator.hasStartedTraining = true
    }

    func currentSessionAnswerID() -> String {
        sessionAnswerID(for: trainingSession.currentIndex)
    }

    func sessionAnswerID(for index: Int) -> String {
        "\(practiceMode.rawValue):\(index)"
    }

    func nextKanjiSessionCards(from sourceCards: [KanjiCard]) -> [KanjiCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextWordSessionCards(from sourceCards: [WordStudyCard]) -> [WordStudyCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextKanaSessionCards(from sourceCards: [KanaStudyCard]) -> [KanaStudyCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextSessionItems<Item: StudyItem>(from sourceItems: [Item]) -> [Item] {
        let result = TrainingSessionEngine.nextSessionItems(
            from: sourceItems,
            reviewStore: reviewStore,
            newCardLimit: kanjiDailyNewCardLimit,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        trainingSession.kanjiSessionPhase = result.phase
        return result.items
    }


    func replaceCard(_ card: KanjiCard) {
        for index in deckState.previewCards.indices where deckState.previewCards[index].kanji == card.kanji {
            deckState.previewCards[index] = deckState.previewCards[index].mergedForDisplay(with: card)
        }

        for index in cards.indices where cards[index].kanji == card.kanji {
            cards[index] = cards[index].mergedForDisplay(with: card)
        }

        coordinator.mergeSelectedKanjiPreview(with: card)

        for index in wordCards.indices {
            wordCards[index] = replacingNestedKanji(card, in: wordCards[index])
        }

        for index in deckState.previewWordCards.indices {
            deckState.previewWordCards[index] = replacingNestedKanji(card, in: deckState.previewWordCards[index])
        }

        if let selectedWordPreviewCard = coordinator.selectedWordPreviewCard {
            coordinator.replaceSelectedWordPreview(replacingNestedKanji(card, in: selectedWordPreviewCard))
        }

        coordinator.mergeLinkedKanjiPreview(with: card)
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

    func openWordPreview(_ deck: WordFrequencyDeck) {
        guard !deckState.isLoadingDeck else {
            return
        }

        selectedWordDeck = deck
        deckState.previewWordDeck = deck
        deckState.previewDeck = nil
        deckState.previewKanaDeck = nil
        coordinator.clearDeckSelection()
        deckState.previewWordCards.removeAll()
        deckState.isLoadingDeck = true

        Task {
            let allWords = await WordDataLoader.loadWords()
            let preparedWords = deck.cards(from: allWords)

            await MainActor.run {
                guard deckState.previewWordDeck == deck else {
                    return
                }

                deckState.previewWordCards = preparedWords
                deckState.isLoadingDeck = false
            }
        }
    }

    func closeWordPreview() {
        deckState.previewWordDeck = nil
        deckState.previewWordCards.removeAll()
        coordinator.closeWordPreview()
        deckState.isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startWordTraining(with trainingCards: [WordStudyCard], sourceCards: [WordStudyCard]? = nil, guided: Bool = false) {
        guard !trainingCards.isEmpty else {
            return
        }

        practiceMode = .words
        deckState.previewWordDeck = nil
        cards.removeAll()
        kanaCards.removeAll()
        deckState.kanjiSourceCards.removeAll()
        deckState.kanaSourceCards.removeAll()
        wordCards = trainingCards
        deckState.wordSourceCards = sourceCards ?? trainingCards
        prepareStudyPack(wordCards, guided: guided)
        deckState.isLoadingDeck = false
        coordinator.hasStartedTraining = true
    }

    func startKanaTraining(
        deck: KanaDeck,
        cards trainingCards: [KanaStudyCard]? = nil,
        sourceCards providedSourceCards: [KanaStudyCard]? = nil,
        guided: Bool = false
    ) {
        selectedKanaDeck = deck
        practiceMode = .kana
        deckState.previewKanaDeck = nil
        cards.removeAll()
        wordCards.removeAll()
        deckState.kanjiSourceCards.removeAll()
        deckState.wordSourceCards.removeAll()
        let sourceCards = providedSourceCards ?? trainingCards ?? deck.cards
        deckState.kanaSourceCards = sourceCards
        kanaCards = trainingCards ?? nextKanaSessionCards(from: sourceCards)
        prepareStudyPack(kanaCards, guided: guided)
        coordinator.hasStartedTraining = !kanaCards.isEmpty
    }

    func loadSelectedDeck() async {
        guard !deckState.isLoadingDeck else {
            return
        }

        deckState.isLoadingDeck = true
        let loadedCards = await KanjiDataLoader.loadCards(deck: selectedDeck)

        guard !loadedCards.isEmpty else {
            deckState.isLoadingDeck = false
            return
        }

        let orderedCards = nextKanjiSessionCards(from: loadedCards)
        deckState.kanjiSourceCards = loadedCards
        cards = orderedCards
        wordCards = WordStudyCard.build(from: loadedCards)
        if practiceMode == .words {
            prepareStudyPack(wordCards, guided: false)
        } else {
            prepareStudyPack(orderedCards, guided: false)
        }
        deckState.isLoadingDeck = false
        coordinator.hasStartedTraining = true
    }

}
