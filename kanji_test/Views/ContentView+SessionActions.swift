import SwiftUI

extension ContentView {
    func resetSessionProgress(total: Int) {
        trainingSession.resetSessionProgress(total: total)
    }

    func resetWordDrawingState(resetKanjiIndex: Bool = true) {
        trainingSession.resetWordDrawingState(resetKanjiIndex: resetKanjiIndex)
    }

    func openKanjiPreviewCard(_ card: KanjiCard) {
        coordinator.selectedPreviewCard = card
        coordinator.previewSwipeDirection = 0
        coordinator.presentedKanjiPreview = PresentedKanjiPreview(card: card)
    }

    func openKanaPreviewCard(_ card: KanaStudyCard) {
        coordinator.selectedKanaPreviewCard = card
        coordinator.previewSwipeDirection = 0
        coordinator.presentedKanaPreview = PresentedKanaPreview(card: card)
    }

    func openWordPreviewCard(_ card: WordStudyCard) {
        coordinator.selectedWordPreviewCard = card
        coordinator.previewSwipeDirection = 0
        coordinator.presentedWordPreview = PresentedWordPreview(card: card)
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
        coordinator.presentedKanjiPreview = nil
        coordinator.presentedKanaPreview = nil
        coordinator.presentedWordPreview = nil
        coordinator.isDeckSchedulePresented = false
        coordinator.selectedPreviewCard = nil
        coordinator.selectedKanaPreviewCard = nil
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedLinkedKanjiCard = nil
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
        coordinator.selectedKanaPreviewCard = nil
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedPreviewCard = nil
        coordinator.isDeckSchedulePresented = false
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
        coordinator.selectedPreviewCard = nil
        coordinator.presentedKanjiPreview = nil
        deckState.isLoadingDeck = false
        coordinator.isDeckSchedulePresented = false
    }

    func openKanaPreview(_ deck: KanaDeck) {
        selectedKanaDeck = deck
        deckState.previewKanaDeck = deck
        deckState.previewDeck = nil
        deckState.previewWordDeck = nil
        deckState.previewWordCards.removeAll()
        deckState.previewKanaCards = deck.baseCards
        coordinator.selectedPreviewCard = nil
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedKanaPreviewCard = nil
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
        coordinator.selectedPreviewCard = nil
        coordinator.selectedKanaPreviewCard = nil
        coordinator.presentedKanaPreview = nil
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
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(cards.map(\.kanji)).count)
        trainingSession.isGuidedSingleKanjiPractice = guided
        coordinator.hasStartedTraining = true
        resetCurrentAnswer()
    }

    func reviewKey(for card: KanjiCard) -> String {
        card.kanji
    }

    func reviewKey(for card: WordStudyCard) -> String {
        "word:\(card.id)"
    }

    func reviewKey(for card: KanaStudyCard) -> String {
        "kana:\(card.character)"
    }

    func currentSessionAnswerID() -> String {
        sessionAnswerID(for: trainingSession.currentIndex)
    }

    func sessionAnswerID(for index: Int) -> String {
        "\(practiceMode.rawValue):\(index)"
    }

    func nextKanjiSessionCards(from sourceCards: [KanjiCard]) -> [KanjiCard] {
        nextSessionItems(from: sourceCards, key: \.kanji)
    }

    func nextWordSessionCards(from sourceCards: [WordStudyCard]) -> [WordStudyCard] {
        nextSessionItems(from: sourceCards, key: reviewKey(for:))
    }

    func nextKanaSessionCards(from sourceCards: [KanaStudyCard]) -> [KanaStudyCard] {
        nextSessionItems(from: sourceCards, key: reviewKey(for:))
    }

    func nextSessionItems<Item>(from sourceItems: [Item], key: (Item) -> String) -> [Item] {
        let result = TrainingSessionEngine.nextSessionItems(
            from: sourceItems,
            reviewStore: reviewStore,
            key: key,
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

        if coordinator.selectedPreviewCard?.kanji == card.kanji {
            coordinator.selectedPreviewCard = coordinator.selectedPreviewCard?.mergedForDisplay(with: card)
        }

        for index in wordCards.indices {
            wordCards[index] = replacingNestedKanji(card, in: wordCards[index])
        }

        for index in deckState.previewWordCards.indices {
            deckState.previewWordCards[index] = replacingNestedKanji(card, in: deckState.previewWordCards[index])
        }

        if let selectedWordPreviewCard = coordinator.selectedWordPreviewCard {
            coordinator.selectedWordPreviewCard = replacingNestedKanji(card, in: selectedWordPreviewCard)
        }

        if coordinator.selectedLinkedKanjiCard?.kanji == card.kanji {
            coordinator.selectedLinkedKanjiCard = coordinator.selectedLinkedKanjiCard?.mergedForDisplay(with: card)
        }
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
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedPreviewCard = nil
        coordinator.selectedKanaPreviewCard = nil
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
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedLinkedKanjiCard = nil
        coordinator.presentedWordPreview = nil
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
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(wordCards.map(\.id)).count)
        trainingSession.isGuidedSingleKanjiPractice = guided
        deckState.isLoadingDeck = false
        coordinator.hasStartedTraining = true
        resetCurrentAnswer()
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
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(kanaCards.map(\.character)).count)
        trainingSession.isGuidedSingleKanjiPractice = guided
        coordinator.hasStartedTraining = !kanaCards.isEmpty
        resetCurrentAnswer()
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
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: practiceMode == .words ? Set(wordCards.map(\.id)).count : Set(orderedCards.map(\.kanji)).count)
        trainingSession.isGuidedSingleKanjiPractice = false
        deckState.isLoadingDeck = false
        coordinator.hasStartedTraining = true
        resetCurrentAnswer()
    }

}
