import SwiftUI

extension ContentView {
    func resetSessionProgress(total: Int) {
        sessionTotalCards = total
        sessionCompletedCards = 0
        masteredKanjiKeys.removeAll()
        masteredWordKeys.removeAll()
        masteredKanaKeys.removeAll()
        sessionAnswerStates.removeAll()
    }

    func resetWordDrawingState(resetKanjiIndex: Bool = true) {
        if resetKanjiIndex {
            currentWordKanjiIndex = 0
        }
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
    }

    func openKanjiPreviewCard(_ card: KanjiCard) {
        selectedPreviewCard = card
        previewSwipeDirection = 0
        presentedKanjiPreview = PresentedKanjiPreview(card: card)
    }

    func openKanaPreviewCard(_ card: KanaStudyCard) {
        selectedKanaPreviewCard = card
        previewSwipeDirection = 0
        presentedKanaPreview = PresentedKanaPreview(card: card)
    }

    func openWordPreviewCard(_ card: WordStudyCard) {
        selectedWordPreviewCard = card
        previewSwipeDirection = 0
        presentedWordPreview = PresentedWordPreview(card: card)
    }

    func clearDeckCache() {
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        KanjiDataLoader.clearCache()
        KanaDataLoader.clearCache()
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        kanjiSourceCards.removeAll()
        wordSourceCards.removeAll()
        kanaSourceCards.removeAll()
        previewCards.removeAll()
        previewKanaCards.removeAll()
        previewWordCards.removeAll()
        previewExpectedCount = nil
        previewDeck = nil
        previewKanaDeck = nil
        previewWordDeck = nil
        presentedKanjiPreview = nil
        presentedKanaPreview = nil
        presentedWordPreview = nil
        isDeckSchedulePresented = false
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        resetCurrentAnswer()
    }

    func openDeckPreview(_ deck: KanjiDeck) {
        deckPreviewTask?.cancel()
        previewDeck = deck
        previewKanaDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards.removeAll()
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedPreviewCard = nil
        isDeckSchedulePresented = false
        previewCards.removeAll()
        previewExpectedCount = nil
        isLoadingDeck = true

        deckPreviewTask = Task {
            await KanjiDataLoader.loadCardsProgressively(deck: deck) { loadedCards, expectedCount in
                guard previewDeck == deck else {
                    return
                }

                previewCards = reviewStore.orderedCards(loadedCards)
                previewExpectedCount = expectedCount
                isLoadingDeck = previewExpectedCount.map { previewCards.count < $0 } ?? false
            }

            if previewDeck == deck {
                isLoadingDeck = false
            }
        }
    }

    func closeDeckPreview() {
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        previewDeck = nil
        previewCards.removeAll()
        previewExpectedCount = nil
        selectedPreviewCard = nil
        presentedKanjiPreview = nil
        isLoadingDeck = false
        isDeckSchedulePresented = false
    }

    func openKanaPreview(_ deck: KanaDeck) {
        selectedKanaDeck = deck
        previewKanaDeck = deck
        previewDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards = deck.baseCards
        selectedPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedKanaPreviewCard = nil
        isLoadingDeck = true
        resetCurrentAnswer()

        Task {
            let loadedCards = await KanaDataLoader.loadCards(deck: deck)
            await MainActor.run {
                guard previewKanaDeck == deck else {
                    return
                }

                previewKanaCards = loadedCards
                isLoadingDeck = false
            }
        }
    }

    func closeKanaPreview() {
        previewKanaDeck = nil
        previewKanaCards.removeAll()
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        presentedKanaPreview = nil
        isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startRandomTrainingFromPreview() {
        startTraining(with: nextKanjiSessionCards(from: previewCards), sourceCards: previewCards, guided: false)
    }

    func startTraining(with trainingCards: [KanjiCard], sourceCards: [KanjiCard]? = nil, guided: Bool) {
        guard !trainingCards.isEmpty else {
            return
        }

        deckPreviewTask?.cancel()
        kanjiSourceCards = sourceCards ?? trainingCards
        cards = trainingCards
        wordCards.removeAll()
        kanaCards.removeAll()
        wordSourceCards.removeAll()
        kanaSourceCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(cards.map(\.kanji)).count)
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = true
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
        sessionAnswerID(for: currentIndex)
    }

    func sessionAnswerID(for index: Int) -> String {
        "\(practiceMode.rawValue):\(index)"
    }

    func learningSessionCards(from sourceCards: [KanjiCard]) -> [KanjiCard] {
        let orderedCards = reviewStore.learningCards(
            from: sourceCards,
            newCardLimit: kanjiDailyNewCardLimit,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        guard orderedCards.isEmpty else {
            return orderedCards
        }

        return Array(sourceCards.shuffled().prefix(max(1, kanjiDailyNewCardLimit)))
    }

    func nextKanjiSessionCards(from sourceCards: [KanjiCard]) -> [KanjiCard] {
        let dueReviewCards = reviewStore.dueReviewCards(
            from: sourceCards,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        if !dueReviewCards.isEmpty {
            kanjiSessionPhase = .review
            return dueReviewCards
        }

        let learningCards = reviewStore.newLearningCards(
            from: sourceCards,
            newCardLimit: kanjiDailyNewCardLimit,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        if !learningCards.isEmpty {
            kanjiSessionPhase = .learning
            return learningCards
        }

        kanjiSessionPhase = .fallbackReview
        return Array(sourceCards.shuffled().prefix(max(1, kanjiDailyNewCardLimit)))
    }

    func nextWordSessionCards(from sourceCards: [WordStudyCard]) -> [WordStudyCard] {
        let dueReviewCards = reviewStore.dueReviewItems(
            from: sourceCards,
            key: reviewKey(for:),
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        if !dueReviewCards.isEmpty {
            kanjiSessionPhase = .review
            return dueReviewCards
        }

        let learningCards = reviewStore.newLearningItems(
            from: sourceCards,
            key: reviewKey(for:),
            newCardLimit: kanjiDailyNewCardLimit
        )
        if !learningCards.isEmpty {
            kanjiSessionPhase = .learning
            return learningCards
        }

        kanjiSessionPhase = .fallbackReview
        return Array(sourceCards.shuffled().prefix(max(1, kanjiDailyNewCardLimit)))
    }

    func nextKanaSessionCards(from sourceCards: [KanaStudyCard]) -> [KanaStudyCard] {
        let dueReviewCards = reviewStore.dueReviewItems(
            from: sourceCards,
            key: reviewKey(for:),
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
        if !dueReviewCards.isEmpty {
            kanjiSessionPhase = .review
            return dueReviewCards
        }

        let learningCards = reviewStore.newLearningItems(
            from: sourceCards,
            key: reviewKey(for:),
            newCardLimit: kanjiDailyNewCardLimit
        )
        if !learningCards.isEmpty {
            kanjiSessionPhase = .learning
            return learningCards
        }

        kanjiSessionPhase = .fallbackReview
        return Array(sourceCards.shuffled().prefix(max(1, kanjiDailyNewCardLimit)))
    }


    func replaceCard(_ card: KanjiCard) {
        for index in previewCards.indices where previewCards[index].kanji == card.kanji {
            previewCards[index] = previewCards[index].mergedForDisplay(with: card)
        }

        for index in cards.indices where cards[index].kanji == card.kanji {
            cards[index] = cards[index].mergedForDisplay(with: card)
        }

        if selectedPreviewCard?.kanji == card.kanji {
            selectedPreviewCard = selectedPreviewCard?.mergedForDisplay(with: card)
        }

        for index in wordCards.indices {
            wordCards[index] = replacingNestedKanji(card, in: wordCards[index])
        }

        for index in previewWordCards.indices {
            previewWordCards[index] = replacingNestedKanji(card, in: previewWordCards[index])
        }

        if let selectedWordPreviewCard {
            self.selectedWordPreviewCard = replacingNestedKanji(card, in: selectedWordPreviewCard)
        }

        if selectedLinkedKanjiCard?.kanji == card.kanji {
            selectedLinkedKanjiCard = selectedLinkedKanjiCard?.mergedForDisplay(with: card)
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
        guard !isLoadingDeck else {
            return
        }

        selectedWordDeck = deck
        previewWordDeck = deck
        previewDeck = nil
        previewKanaDeck = nil
        selectedWordPreviewCard = nil
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        previewWordCards.removeAll()
        isLoadingDeck = true

        Task {
            let allWords = await WordDataLoader.loadWords()
            let preparedWords = deck.cards(from: allWords)

            await MainActor.run {
                guard previewWordDeck == deck else {
                    return
                }

                previewWordCards = preparedWords
                isLoadingDeck = false
            }
        }
    }

    func closeWordPreview() {
        previewWordDeck = nil
        previewWordCards.removeAll()
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        presentedWordPreview = nil
        isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startWordTraining(with trainingCards: [WordStudyCard], sourceCards: [WordStudyCard]? = nil, guided: Bool = false) {
        guard !trainingCards.isEmpty else {
            return
        }

        practiceMode = .words
        previewWordDeck = nil
        cards.removeAll()
        kanaCards.removeAll()
        kanjiSourceCards.removeAll()
        kanaSourceCards.removeAll()
        wordCards = trainingCards
        wordSourceCards = sourceCards ?? trainingCards
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(wordCards.map(\.id)).count)
        isGuidedSingleKanjiPractice = guided
        isLoadingDeck = false
        hasStartedTraining = true
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
        previewKanaDeck = nil
        cards.removeAll()
        wordCards.removeAll()
        kanjiSourceCards.removeAll()
        wordSourceCards.removeAll()
        let sourceCards = providedSourceCards ?? trainingCards ?? deck.cards
        kanaSourceCards = sourceCards
        kanaCards = trainingCards ?? nextKanaSessionCards(from: sourceCards)
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(kanaCards.map(\.character)).count)
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = !kanaCards.isEmpty
        resetCurrentAnswer()
    }

    func loadSelectedDeck() async {
        guard !isLoadingDeck else {
            return
        }

        isLoadingDeck = true
        let loadedCards = await KanjiDataLoader.loadCards(deck: selectedDeck)

        guard !loadedCards.isEmpty else {
            isLoadingDeck = false
            return
        }

        let orderedCards = nextKanjiSessionCards(from: loadedCards)
        kanjiSourceCards = loadedCards
        cards = orderedCards
        wordCards = WordStudyCard.build(from: loadedCards)
        currentIndex = 0
        resetWordDrawingState()
        resetSessionProgress(total: practiceMode == .words ? Set(wordCards.map(\.id)).count : Set(orderedCards.map(\.kanji)).count)
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = true
        resetCurrentAnswer()
    }

}
