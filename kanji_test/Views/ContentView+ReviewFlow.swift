import SwiftUI

extension ContentView {
    func applyWordReview(_ rating: ReviewRating) {
        guard wordCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        let wordCard = wordCards[currentIndex]
        switch rating {
        case .again:
            masteredWordKeys.remove(wordCard.id)
            scheduleWordRepeat(wordCard, after: 2)
        case .hard:
            masteredWordKeys.remove(wordCard.id)
            scheduleWordRepeat(wordCard, after: 5)
        case .good:
            masteredWordKeys.insert(wordCard.id)
            removeFutureWordRepeats(after: currentIndex, key: wordCard.id)
        }

        sessionCompletedCards = masteredWordKeys.count
        advanceToNextWordOrFinish()
    }

    func scheduleWordRepeat(_ wordCard: WordStudyCard, after offset: Int) {
        removeFutureWordRepeats(after: currentIndex, key: wordCard.id)
        let insertIndex = min(currentIndex + offset, wordCards.count)
        wordCards.insert(wordCard, at: insertIndex)
    }

    func removeFutureWordRepeats(after index: Int, key: String) {
        guard index + 1 < wordCards.count else {
            return
        }

        for cardIndex in wordCards.indices.reversed() where cardIndex > index && wordCards[cardIndex].id == key {
            wordCards.remove(at: cardIndex)
        }
    }

    func advanceToNextWordOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            finishDeck()
            return
        }

        guard currentIndex < wordCards.count - 1 else {
            return
        }

        currentIndex += 1
        resetWordDrawingState()
        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    func applyKanaReview(_ rating: ReviewRating) {
        guard kanaCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        let kanaCard = kanaCards[currentIndex]
        switch rating {
        case .again:
            masteredKanaKeys.remove(kanaCard.character)
            scheduleKanaRepeat(kanaCard, after: 2)
        case .hard:
            masteredKanaKeys.remove(kanaCard.character)
            scheduleKanaRepeat(kanaCard, after: 5)
        case .good:
            masteredKanaKeys.insert(kanaCard.character)
            removeFutureKanaRepeats(after: currentIndex, key: kanaCard.character)
        }

        sessionCompletedCards = masteredKanaKeys.count
        advanceToNextKanaOrFinish()
    }

    func scheduleKanaRepeat(_ kanaCard: KanaStudyCard, after offset: Int) {
        removeFutureKanaRepeats(after: currentIndex, key: kanaCard.character)
        let insertIndex = min(currentIndex + offset, kanaCards.count)
        kanaCards.insert(kanaCard, at: insertIndex)
    }

    func removeFutureKanaRepeats(after index: Int, key: String) {
        guard index + 1 < kanaCards.count else {
            return
        }

        for cardIndex in kanaCards.indices.reversed() where cardIndex > index && kanaCards[cardIndex].character == key {
            kanaCards.remove(at: cardIndex)
        }
    }

    func advanceToNextKanaOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            finishDeck()
            return
        }

        guard currentIndex < kanaCards.count - 1 else {
            return
        }

        currentIndex += 1
        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        guard !isPreparingCard else {
            return
        }

        Task { @MainActor in
            await applyReviewAndAdvance(rating, to: card)
        }
    }

    func applyReviewAndAdvance(_ rating: ReviewRating, to card: KanjiCard) async {
        guard cards.indices.contains(currentIndex), cards[currentIndex].kanji == card.kanji else {
            return
        }

        let successTarget = max(1, kanjiLearningSuccessTarget)
        let wasLearnedBefore = (reviewStore.record(for: card.kanji)?.successes ?? 0) >= successTarget
        let shouldResetIntervalOnGood = rating == .good && wasLearnedBefore && kanjiAgainCounts[card.kanji, default: 0] >= 2
        reviewStore.apply(
            rating,
            to: card.kanji,
            learningSuccessTarget: kanjiLearningSuccessTarget,
            resetIntervalOnGood: shouldResetIntervalOnGood
        )
        let reviewRecord = reviewStore.record(for: card.kanji)
        let isLearned = (reviewRecord?.successes ?? 0) >= successTarget

        switch rating {
        case .again:
            masteredKanjiKeys.remove(card.kanji)
            kanjiAgainCounts[card.kanji, default: 0] += 1
            kanjiRecoveryGoodCounts[card.kanji] = 0
            scheduleKanjiRepeat(card, after: 2)
            if kanjiAgainCounts[card.kanji, default: 0] >= 3 {
                scheduleAdditionalKanjiRepeat(card, after: 5)
            }
        case .hard:
            masteredKanjiKeys.remove(card.kanji)
            scheduleKanjiRepeat(card, after: 5)
        case .good:
            if isLearned {
                if needsMoreRecoverySuccesses(for: card.kanji) {
                    masteredKanjiKeys.remove(card.kanji)
                    scheduleKanjiRepeatAtEnd(card)
                } else {
                    masteredKanjiKeys.insert(card.kanji)
                    kanjiAgainCounts[card.kanji] = nil
                    kanjiRecoveryGoodCounts[card.kanji] = nil
                    removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
                }
            } else {
                masteredKanjiKeys.remove(card.kanji)
                scheduleKanjiRepeatAtEnd(card)
            }
        }

        sessionCompletedCards = masteredKanjiKeys.count
        await advanceToNextKanjiOrFinish()
    }

    func needsMoreRecoverySuccesses(for kanji: String) -> Bool {
        let mistakeCount = kanjiAgainCounts[kanji, default: 0]
        guard mistakeCount >= 2 else {
            return false
        }

        let requiredGoodCount = 1 + (mistakeCount / 2)
        kanjiRecoveryGoodCounts[kanji, default: 0] += 1
        return kanjiRecoveryGoodCounts[kanji, default: 0] < requiredGoodCount
    }

    func scheduleKanjiRepeat(_ card: KanjiCard, after offset: Int) {
        removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
        scheduleAdditionalKanjiRepeat(card, after: offset)
    }

    func scheduleAdditionalKanjiRepeat(_ card: KanjiCard, after offset: Int) {
        let insertIndex = min(currentIndex + offset, cards.count)
        cards.insert(card, at: insertIndex)
    }

    func scheduleKanjiRepeatAtEnd(_ card: KanjiCard) {
        removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
        cards.append(card)
    }

    func removeFutureKanjiRepeats(after index: Int, key: String) {
        guard index + 1 < cards.count else {
            return
        }

        for cardIndex in cards.indices.reversed() where cardIndex > index && cards[cardIndex].kanji == key {
            cards.remove(at: cardIndex)
        }
    }

    func advanceToNextKanjiOrFinish() async {
        guard sessionCompletedCards < sessionTotalCards else {
            if !isGuidedSingleKanjiPractice, startNextKanjiPack() {
                return
            }

            finishDeck()
            return
        }

        guard currentIndex < cards.count - 1 else {
            return
        }

        await prepareAndMoveToCard(at: currentIndex + 1)
    }

    func startNextKanjiPack() -> Bool {
        let sourceCards = !kanjiSourceCards.isEmpty ? kanjiSourceCards : previewCards
        let nextCards = nextKanjiSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        cards = nextCards
        wordCards.removeAll()
        kanaCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.kanji)).count)
        isPreparingCard = false
        resetCurrentAnswer()
        scrollToTopToken += 1
        return true
    }

    func finishDeck() {
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        kanjiSourceCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        isGuidedSingleKanjiPractice = false
        isPreparingCard = false
        hasStartedTraining = false
        resetCurrentAnswer()
    }

    func moveToPreviousCard() {
        guard currentIndex > 0, !isPreparingCard else {
            return
        }

        currentIndex -= 1
        resetWordDrawingState()
        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    func moveToNextCard() {
        guard !isPreparingCard else {
            return
        }

        switch practiceMode {
        case .kanji:
            guard currentIndex < cards.count - 1 else {
                return
            }
            let targetIndex = currentIndex + 1
            Task { @MainActor in
                await prepareAndMoveToCard(at: targetIndex)
            }
        case .words:
            guard currentIndex < wordCards.count - 1 else {
                return
            }
            currentIndex += 1
            resetWordDrawingState()
            resetCurrentAnswer()
            scrollToTopToken += 1
        case .kana:
            guard currentIndex < kanaCards.count - 1 else {
                return
            }
            currentIndex += 1
            resetCurrentAnswer()
            scrollToTopToken += 1
        }
    }

    func prepareAndMoveToCard(at targetIndex: Int) async {
        guard cards.indices.contains(targetIndex), !isPreparingCard else {
            return
        }

        isPreparingCard = true

        let deck = selectedDeck

        guard selectedDeck == deck, cards.indices.contains(targetIndex) else {
            isPreparingCard = false
            return
        }

        currentIndex = targetIndex
        resetCurrentAnswer()
        scrollToTopToken += 1
        isPreparingCard = false
    }

    func resetCurrentAnswer() {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        showsFeedbackInfo = false
        guidedStrokeLimit = 1
        isAnswerVisible = false
    }

    func updateFeedback(for card: KanjiCard, reveal: Bool) {
        feedback = StrokeEvaluator.evaluate(actual: drawnStrokes, expected: card.strokes)

        if reveal {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible = true
            }
        }
    }
}
