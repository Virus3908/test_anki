import SwiftUI

extension ContentView {
    func applyWordReview(_ rating: ReviewRating) {
        guard wordCards.indices.contains(trainingSession.currentIndex), !trainingSession.isPreparingCard else {
            return
        }

        let wordCard = wordCards[trainingSession.currentIndex]
        let key = reviewKey(for: wordCard)
        let answerID = currentSessionAnswerID()
        let existingAnswer = trainingSession.sessionAnswerStates[answerID]
        prepareReviewReapply(existingAnswer) {
            removeFutureRepeats(after: trainingSession.currentIndex, key: key, from: &wordCards, keyFor: reviewKey(for:))
        }

        let shouldAdvance = applyReviewedItem(
            wordCard,
            rating: rating,
            key: key,
            existingAnswer: existingAnswer,
            masteredKeys: &trainingSession.masteredWordKeys,
            items: &wordCards,
            keyFor: reviewKey(for:)
        )

        if !shouldAdvance {
            return
        }

        advanceToNextWordOrFinish()
    }

    func advanceToNextWordOrFinish() {
        guard trainingSession.sessionCompletedCards < trainingSession.sessionTotalCards else {
            if startNextWordPack() {
                return
            }

            finishDeck()
            return
        }

        guard trainingSession.currentIndex < wordCards.count - 1 else {
            return
        }

        trainingSession.currentIndex += 1
        resetWordDrawingState()
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
    }

    func applyKanaReview(_ rating: ReviewRating) {
        guard kanaCards.indices.contains(trainingSession.currentIndex), !trainingSession.isPreparingCard else {
            return
        }

        let kanaCard = kanaCards[trainingSession.currentIndex]
        let key = reviewKey(for: kanaCard)
        let answerID = currentSessionAnswerID()
        let existingAnswer = trainingSession.sessionAnswerStates[answerID]
        prepareReviewReapply(existingAnswer) {
            removeFutureRepeats(after: trainingSession.currentIndex, key: key, from: &kanaCards, keyFor: reviewKey(for:))
        }

        let shouldAdvance = applyReviewedItem(
            kanaCard,
            rating: rating,
            key: key,
            existingAnswer: existingAnswer,
            masteredKeys: &trainingSession.masteredKanaKeys,
            items: &kanaCards,
            keyFor: reviewKey(for:)
        )

        if !shouldAdvance {
            return
        }

        advanceToNextKanaOrFinish()
    }

    func advanceToNextKanaOrFinish() {
        guard trainingSession.sessionCompletedCards < trainingSession.sessionTotalCards else {
            if startNextKanaPack() {
                return
            }

            finishDeck()
            return
        }

        guard trainingSession.currentIndex < kanaCards.count - 1 else {
            return
        }

        trainingSession.currentIndex += 1
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
    }

    func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        guard !trainingSession.isPreparingCard else {
            return
        }

        Task { @MainActor in
            await applyReviewAndAdvance(rating, to: card)
        }
    }

    func applyReviewAndAdvance(_ rating: ReviewRating, to card: KanjiCard) async {
        guard cards.indices.contains(trainingSession.currentIndex), cards[trainingSession.currentIndex].kanji == card.kanji else {
            return
        }

        let key = reviewKey(for: card)
        let answerID = currentSessionAnswerID()
        let existingAnswer = trainingSession.sessionAnswerStates[answerID]
        prepareReviewReapply(existingAnswer) {
            removeFutureRepeats(after: trainingSession.currentIndex, key: key, from: &cards, keyFor: \.kanji)
        }

        let shouldAdvance = applyReviewedItem(
            card,
            rating: rating,
            key: key,
            existingAnswer: existingAnswer,
            masteredKeys: &trainingSession.masteredKanjiKeys,
            items: &cards,
            keyFor: \.kanji
        )

        if !shouldAdvance {
            return
        }

        await advanceToNextKanjiOrFinish()
    }

    func restoreSessionAnswer(_ answer: SessionAnswerState) {
        reviewStore.restore(answer.recordBefore, for: answer.reviewKey)
        restoreCounter(answer.againCountBefore, for: answer.reviewKey, in: &trainingSession.kanjiAgainCounts)
        restoreCounter(answer.recoveryGoodCountBefore, for: answer.reviewKey, in: &trainingSession.kanjiRecoveryGoodCounts)

        switch practiceMode {
        case .kanji:
            if answer.wasMastered {
                trainingSession.masteredKanjiKeys.insert(answer.reviewKey)
            } else {
                trainingSession.masteredKanjiKeys.remove(answer.reviewKey)
            }
            trainingSession.sessionCompletedCards = trainingSession.masteredKanjiKeys.count
        case .words:
            if answer.wasMastered {
                trainingSession.masteredWordKeys.insert(answer.reviewKey)
            } else {
                trainingSession.masteredWordKeys.remove(answer.reviewKey)
            }
            trainingSession.sessionCompletedCards = trainingSession.masteredWordKeys.count
        case .kana:
            if answer.wasMastered {
                trainingSession.masteredKanaKeys.insert(answer.reviewKey)
            } else {
                trainingSession.masteredKanaKeys.remove(answer.reviewKey)
            }
            trainingSession.sessionCompletedCards = trainingSession.masteredKanaKeys.count
        }
    }

    func prepareReviewReapply(
        _ existingAnswer: SessionAnswerState?,
        removeFutureRepeats: () -> Void
    ) {
        guard let existingAnswer else {
            return
        }

        restoreSessionAnswer(existingAnswer)
        removeFutureRepeats()
        rollbackFutureSessionAnswers(after: trainingSession.currentIndex)
    }

    func applyReviewedItem<Item>(
        _ reviewedItem: Item,
        rating: ReviewRating,
        key: String,
        existingAnswer: SessionAnswerState?,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        keyFor: (Item) -> String
    ) -> Bool {
        var answerState = existingAnswer ?? TrainingSessionEngine.makeAnswerState(
            reviewKey: key,
            rating: rating,
            recordBefore: reviewStore.record(for: key),
            againCountBefore: trainingSession.kanjiAgainCounts[key],
            recoveryGoodCountBefore: trainingSession.kanjiRecoveryGoodCounts[key],
            wasMastered: masteredKeys.contains(key)
        )
        let answerPlan = makeAndApplyAnswerPlan(for: key, rating: rating)
        let isLearned = reviewStore.record(for: key)?.state == .review

        if rating == .again {
            trainingSession.kanjiAgainCounts[key, default: 0] += 1
            trainingSession.kanjiRecoveryGoodCounts[key] = 0
        }

        let queueDecision = TrainingSessionEngine.makeQueueDecision(
            rating: rating,
            isLearned: isLearned,
            needsMoreRecovery: answerPlan.needsMoreRecovery,
            mistakeCount: trainingSession.kanjiAgainCounts[key, default: 0]
        )

        applyQueueDecision(
            queueDecision,
            item: reviewedItem,
            key: key,
            masteredKeys: &masteredKeys,
            items: &items,
            keyFor: keyFor
        )

        trainingSession.sessionCompletedCards = masteredKeys.count
        answerState.rating = rating
        trainingSession.sessionAnswerStates[currentSessionAnswerID()] = answerState
        return existingAnswer == nil
    }

    func makeAndApplyAnswerPlan(for key: String, rating: ReviewRating) -> ReviewAnswerPlan {
        let answerPlan = TrainingSessionEngine.makeAnswerPlan(
            rating: rating,
            record: reviewStore.record(for: key),
            phase: trainingSession.kanjiSessionPhase,
            mistakeCount: trainingSession.kanjiAgainCounts[key, default: 0],
            recoveryGoodCount: trainingSession.kanjiRecoveryGoodCounts[key, default: 0]
        )
        if let updatedRecoveryGoodCount = answerPlan.updatedRecoveryGoodCount {
            trainingSession.kanjiRecoveryGoodCounts[key] = updatedRecoveryGoodCount
        }

        if answerPlan.shouldUpdateSchedule {
            reviewStore.apply(
                rating,
                to: key,
                learningSuccessTarget: kanjiLearningSuccessTarget,
                resetIntervalOnGood: answerPlan.shouldResetIntervalOnGood
            )
        }

        return answerPlan
    }

    func applyQueueDecision<Item>(
        _ decision: ReviewQueueDecision,
        item: Item,
        key: String,
        masteredKeys: inout Set<String>,
        items: inout [Item],
        keyFor: (Item) -> String
    ) {
        if decision.isMastered {
            masteredKeys.insert(key)
        } else {
            masteredKeys.remove(key)
        }

        TrainingSessionEngine.applyQueueDecision(
            decision,
            item: item,
            key: key,
            currentIndex: trainingSession.currentIndex,
            items: &items,
            keyFor: keyFor
        )

        if decision.shouldClearRecoveryCounters {
            trainingSession.kanjiAgainCounts[key] = nil
            trainingSession.kanjiRecoveryGoodCounts[key] = nil
        }
    }

    func restoreCounter(_ value: Int?, for key: String, in dictionary: inout [String: Int]) {
        if let value {
            dictionary[key] = value
        } else {
            dictionary[key] = nil
        }
    }

    func rollbackFutureSessionAnswers(after index: Int) {
        let prefix = "\(practiceMode.rawValue):"

        let futureAnswers = trainingSession.sessionAnswerStates.compactMap { answerID, answer -> (String, Int, SessionAnswerState)? in
            guard answerID.hasPrefix(prefix) else {
                return nil
            }

            let indexText = answerID.dropFirst(prefix.count)
            guard let answerIndex = Int(indexText), answerIndex > index else {
                return nil
            }

            return (answerID, answerIndex, answer)
        }
        .sorted { left, right in
            left.1 > right.1
        }

        for (answerID, _, answer) in futureAnswers {
            restoreSessionAnswer(answer)
            removeFutureRepeatsForCurrentMode(after: index, key: answer.reviewKey)
            trainingSession.sessionAnswerStates[answerID] = nil
        }
    }

    func removeFutureRepeatsForCurrentMode(after index: Int, key: String) {
        switch practiceMode {
        case .kanji:
            removeFutureRepeats(after: index, key: key, from: &cards, keyFor: \.kanji)
        case .words:
            removeFutureRepeats(after: index, key: key, from: &wordCards, keyFor: reviewKey(for:))
        case .kana:
            removeFutureRepeats(after: index, key: key, from: &kanaCards, keyFor: reviewKey(for:))
        }
    }

    func removeFutureRepeats<Item>(
        after index: Int,
        key: String,
        from items: inout [Item],
        keyFor: (Item) -> String
    ) {
        TrainingSessionEngine.removeFutureRepeats(
            after: index,
            key: key,
            items: &items,
            keyFor: keyFor
        )
    }

    func clearFutureSessionAnswers(after index: Int) {
        let prefix = "\(practiceMode.rawValue):"
        let answerIDs = trainingSession.sessionAnswerStates.keys.filter { answerID in
            guard answerID.hasPrefix(prefix) else {
                return false
            }

            let indexText = answerID.dropFirst(prefix.count)
            return Int(indexText).map { $0 > index } ?? false
        }

        for answerID in answerIDs {
            trainingSession.sessionAnswerStates[answerID] = nil
        }
    }

    func advanceToNextKanjiOrFinish() async {
        guard trainingSession.sessionCompletedCards < trainingSession.sessionTotalCards else {
            if !trainingSession.isGuidedSingleKanjiPractice, startNextKanjiPack() {
                return
            }

            finishDeck()
            return
        }

        guard trainingSession.currentIndex < cards.count - 1 else {
            return
        }

        await prepareAndMoveToCard(at: trainingSession.currentIndex + 1)
    }

    func startNextWordPack() -> Bool {
        let sourceCards = !deckState.wordSourceCards.isEmpty ? deckState.wordSourceCards : deckState.previewWordCards
        guard !sourceCards.isEmpty, !trainingSession.isGuidedSingleKanjiPractice else {
            return false
        }

        let nextCards = nextWordSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        wordCards = nextCards
        cards.removeAll()
        kanaCards.removeAll()
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.id)).count)
        trainingSession.isPreparingCard = false
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
        return true
    }

    func startNextKanaPack() -> Bool {
        let sourceCards = !deckState.kanaSourceCards.isEmpty ? deckState.kanaSourceCards : deckState.previewKanaCards
        guard !sourceCards.isEmpty, !trainingSession.isGuidedSingleKanjiPractice else {
            return false
        }

        let nextCards = nextKanaSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        kanaCards = nextCards
        cards.removeAll()
        wordCards.removeAll()
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.character)).count)
        trainingSession.isPreparingCard = false
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
        return true
    }

    func startNextKanjiPack() -> Bool {
        let sourceCards = !deckState.kanjiSourceCards.isEmpty ? deckState.kanjiSourceCards : deckState.previewCards
        let nextCards = nextKanjiSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        cards = nextCards
        wordCards.removeAll()
        kanaCards.removeAll()
        trainingSession.resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.kanji)).count)
        trainingSession.isPreparingCard = false
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
        return true
    }

    func finishDeck() {
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        deckState.kanjiSourceCards.removeAll()
        deckState.wordSourceCards.removeAll()
        deckState.kanaSourceCards.removeAll()
        trainingSession.resetQueuePosition()
        trainingSession.kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        trainingSession.isGuidedSingleKanjiPractice = false
        trainingSession.isPreparingCard = false
        coordinator.hasStartedTraining = false
        coordinator.selectedPreviewCard = nil
        coordinator.selectedKanaPreviewCard = nil
        coordinator.selectedWordPreviewCard = nil
        coordinator.selectedLinkedKanjiCard = nil
        coordinator.presentedKanjiPreview = nil
        coordinator.presentedKanaPreview = nil
        coordinator.presentedWordPreview = nil
        resetCurrentAnswer()
    }

    func moveToPreviousCard() {
        guard trainingSession.currentIndex > 0, !trainingSession.isPreparingCard else {
            return
        }

        trainingSession.currentIndex -= 1
        resetWordDrawingState()
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
    }

    func moveToNextCard() {
        guard !trainingSession.isPreparingCard else {
            return
        }

        switch practiceMode {
        case .kanji:
            guard trainingSession.currentIndex < cards.count - 1 else {
                return
            }
            let targetIndex = trainingSession.currentIndex + 1
            Task { @MainActor in
                await prepareAndMoveToCard(at: targetIndex)
            }
        case .words:
            guard trainingSession.currentIndex < wordCards.count - 1 else {
                return
            }
            trainingSession.currentIndex += 1
            resetWordDrawingState()
            resetCurrentAnswer()
            trainingSession.scrollToTopToken += 1
        case .kana:
            guard trainingSession.currentIndex < kanaCards.count - 1 else {
                return
            }
            trainingSession.currentIndex += 1
            resetCurrentAnswer()
            trainingSession.scrollToTopToken += 1
        }
    }

    func prepareAndMoveToCard(at targetIndex: Int) async {
        guard cards.indices.contains(targetIndex), !trainingSession.isPreparingCard else {
            return
        }

        trainingSession.isPreparingCard = true

        let deck = selectedDeck

        guard selectedDeck == deck, cards.indices.contains(targetIndex) else {
            trainingSession.isPreparingCard = false
            return
        }

        trainingSession.currentIndex = targetIndex
        resetCurrentAnswer()
        trainingSession.scrollToTopToken += 1
        trainingSession.isPreparingCard = false
    }

    func resetCurrentAnswer() {
        trainingSession.resetCurrentAnswer()
    }

    func updateFeedback(for card: KanjiCard, reveal: Bool) {
        trainingSession.feedback = StrokeEvaluator.evaluate(actual: trainingSession.drawnStrokes, expected: card.strokes)

        if reveal {
            withAnimation(.easeInOut(duration: 0.24)) {
                trainingSession.isAnswerVisible = true
            }
        }
    }
}
