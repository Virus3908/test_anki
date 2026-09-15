import SwiftUI

extension ContentView {
    func resetSessionProgress(total: Int) {
        sessionTotalCards = total
        sessionCompletedCards = 0
        masteredKanjiKeys.removeAll()
        masteredWordKeys.removeAll()
        masteredKanaKeys.removeAll()
    }

    func clearDeckCache() {
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        KanjiDataLoader.clearCache()
        KanaDataLoader.clearCache()
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        previewCards.removeAll()
        previewKanaCards.removeAll()
        previewWordCards.removeAll()
        previewExpectedCount = nil
        previewDeck = nil
        previewKanaDeck = nil
        previewWordDeck = nil
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
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
        isPreviewDetailPresented = false
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
        isLoadingDeck = false
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
        isPreviewDetailPresented = false
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
        isPreviewDetailPresented = false
        isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startRandomTrainingFromPreview() {
        startTraining(with: previewCards.shuffled(), guided: false)
    }

    func startTraining(with trainingCards: [KanjiCard], guided: Bool) {
        guard !trainingCards.isEmpty else {
            return
        }

        deckPreviewTask?.cancel()
        cards = trainingCards
        wordCards.removeAll()
        kanaCards.removeAll()
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: Set(cards.map(\.kanji)).count)
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = true
        resetCurrentAnswer()
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
        isPreviewDetailPresented = false
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
        isPreviewDetailPresented = false
        isLinkedKanjiPresented = false
        isLoadingDeck = false
        resetCurrentAnswer()
    }

    func startWordTraining(with trainingCards: [WordStudyCard]) {
        guard !trainingCards.isEmpty else {
            return
        }

        practiceMode = .words
        previewWordDeck = nil
        cards.removeAll()
        kanaCards.removeAll()
        wordCards = trainingCards
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: Set(wordCards.map(\.id)).count)
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = true
        resetCurrentAnswer()
    }

    func startKanaTraining(deck: KanaDeck, cards trainingCards: [KanaStudyCard]? = nil, guided: Bool = false) {
        selectedKanaDeck = deck
        practiceMode = .kana
        previewKanaDeck = nil
        cards.removeAll()
        wordCards.removeAll()
        kanaCards = trainingCards ?? deck.cards.shuffled()
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
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

        let orderedCards = reviewStore.orderedCards(loadedCards)
        cards = orderedCards
        wordCards = WordStudyCard.build(from: orderedCards)
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: practiceMode == .words ? Set(wordCards.map(\.id)).count : Set(orderedCards.map(\.kanji)).count)
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = true
        resetCurrentAnswer()
    }

}
