import SwiftUI

extension ContentView {
    func applyWordReview(_ rating: ReviewRating) {
        guard wordCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        let wordCard = wordCards[currentIndex]
        let key = reviewKey(for: wordCard)
        let answerID = currentSessionAnswerID()
        let existingAnswer = sessionAnswerStates[answerID]
        if let existingAnswer {
            restoreSessionAnswer(existingAnswer)
            removeFutureWordRepeats(after: currentIndex, key: key)
            rollbackFutureSessionAnswers(after: currentIndex)
        }

        var answerState = existingAnswer ?? SessionAnswerState(
            reviewKey: key,
            rating: rating,
            recordBefore: reviewStore.record(for: key),
            againCountBefore: kanjiAgainCounts[key],
            recoveryGoodCountBefore: kanjiRecoveryGoodCounts[key],
            wasMastered: masteredWordKeys.contains(key)
        )
        let wasReviewCard = reviewStore.record(for: key)?.state == .review
        let needsMoreRecovery = rating == .good && needsMoreRecoverySuccesses(for: key)
        let shouldUpdateSchedule = kanjiSessionPhase != .fallbackReview && !needsMoreRecovery
        let shouldResetIntervalOnGood = rating == .good && wasReviewCard && kanjiAgainCounts[key, default: 0] >= 2

        if shouldUpdateSchedule {
            reviewStore.apply(
                rating,
                to: key,
                learningSuccessTarget: kanjiLearningSuccessTarget,
                resetIntervalOnGood: shouldResetIntervalOnGood
            )
        }

        let isLearned = reviewStore.record(for: key)?.state == .review

        switch rating {
        case .again:
            masteredWordKeys.remove(key)
            kanjiAgainCounts[key, default: 0] += 1
            kanjiRecoveryGoodCounts[key] = 0
            scheduleWordRepeat(wordCard, after: 2)
            if kanjiAgainCounts[key, default: 0] >= 3 {
                scheduleAdditionalWordRepeat(wordCard, after: 5)
            }
        case .hard:
            masteredWordKeys.remove(key)
            scheduleWordRepeat(wordCard, after: 5)
        case .good:
            if isLearned {
                if needsMoreRecovery {
                    masteredWordKeys.remove(key)
                    scheduleWordRepeatAtEnd(wordCard)
                } else {
                    masteredWordKeys.insert(key)
                    kanjiAgainCounts[key] = nil
                    kanjiRecoveryGoodCounts[key] = nil
                    removeFutureWordRepeats(after: currentIndex, key: key)
                }
            } else {
                masteredWordKeys.remove(key)
                scheduleWordRepeatAtEnd(wordCard)
            }
        }

        sessionCompletedCards = masteredWordKeys.count
        answerState.rating = rating
        sessionAnswerStates[answerID] = answerState
        if existingAnswer != nil {
            return
        }

        advanceToNextWordOrFinish()
    }

    func scheduleWordRepeat(_ wordCard: WordStudyCard, after offset: Int) {
        removeFutureWordRepeats(after: currentIndex, key: reviewKey(for: wordCard))
        scheduleAdditionalWordRepeat(wordCard, after: offset)
    }

    func scheduleAdditionalWordRepeat(_ wordCard: WordStudyCard, after offset: Int) {
        let insertIndex = min(currentIndex + offset, wordCards.count)
        wordCards.insert(wordCard, at: insertIndex)
    }

    func scheduleWordRepeatAtEnd(_ wordCard: WordStudyCard) {
        removeFutureWordRepeats(after: currentIndex, key: reviewKey(for: wordCard))
        wordCards.append(wordCard)
    }

    func removeFutureWordRepeats(after index: Int, key: String) {
        guard index + 1 < wordCards.count else {
            return
        }

        for cardIndex in wordCards.indices.reversed() where cardIndex > index && reviewKey(for: wordCards[cardIndex]) == key {
            wordCards.remove(at: cardIndex)
        }
    }

    func advanceToNextWordOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            if startNextWordPack() {
                return
            }

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
        let key = reviewKey(for: kanaCard)
        let answerID = currentSessionAnswerID()
        let existingAnswer = sessionAnswerStates[answerID]
        if let existingAnswer {
            restoreSessionAnswer(existingAnswer)
            removeFutureKanaRepeats(after: currentIndex, key: key)
            rollbackFutureSessionAnswers(after: currentIndex)
        }

        var answerState = existingAnswer ?? SessionAnswerState(
            reviewKey: key,
            rating: rating,
            recordBefore: reviewStore.record(for: key),
            againCountBefore: kanjiAgainCounts[key],
            recoveryGoodCountBefore: kanjiRecoveryGoodCounts[key],
            wasMastered: masteredKanaKeys.contains(key)
        )
        let wasReviewCard = reviewStore.record(for: key)?.state == .review
        let needsMoreRecovery = rating == .good && needsMoreRecoverySuccesses(for: key)
        let shouldUpdateSchedule = kanjiSessionPhase != .fallbackReview && !needsMoreRecovery
        let shouldResetIntervalOnGood = rating == .good && wasReviewCard && kanjiAgainCounts[key, default: 0] >= 2

        if shouldUpdateSchedule {
            reviewStore.apply(
                rating,
                to: key,
                learningSuccessTarget: kanjiLearningSuccessTarget,
                resetIntervalOnGood: shouldResetIntervalOnGood
            )
        }

        let isLearned = reviewStore.record(for: key)?.state == .review

        switch rating {
        case .again:
            masteredKanaKeys.remove(key)
            kanjiAgainCounts[key, default: 0] += 1
            kanjiRecoveryGoodCounts[key] = 0
            scheduleKanaRepeat(kanaCard, after: 2)
            if kanjiAgainCounts[key, default: 0] >= 3 {
                scheduleAdditionalKanaRepeat(kanaCard, after: 5)
            }
        case .hard:
            masteredKanaKeys.remove(key)
            scheduleKanaRepeat(kanaCard, after: 5)
        case .good:
            if isLearned {
                if needsMoreRecovery {
                    masteredKanaKeys.remove(key)
                    scheduleKanaRepeatAtEnd(kanaCard)
                } else {
                    masteredKanaKeys.insert(key)
                    kanjiAgainCounts[key] = nil
                    kanjiRecoveryGoodCounts[key] = nil
                    removeFutureKanaRepeats(after: currentIndex, key: key)
                }
            } else {
                masteredKanaKeys.remove(key)
                scheduleKanaRepeatAtEnd(kanaCard)
            }
        }

        sessionCompletedCards = masteredKanaKeys.count
        answerState.rating = rating
        sessionAnswerStates[answerID] = answerState
        if existingAnswer != nil {
            return
        }

        advanceToNextKanaOrFinish()
    }

    func scheduleKanaRepeat(_ kanaCard: KanaStudyCard, after offset: Int) {
        removeFutureKanaRepeats(after: currentIndex, key: reviewKey(for: kanaCard))
        scheduleAdditionalKanaRepeat(kanaCard, after: offset)
    }

    func scheduleAdditionalKanaRepeat(_ kanaCard: KanaStudyCard, after offset: Int) {
        let insertIndex = min(currentIndex + offset, kanaCards.count)
        kanaCards.insert(kanaCard, at: insertIndex)
    }

    func scheduleKanaRepeatAtEnd(_ kanaCard: KanaStudyCard) {
        removeFutureKanaRepeats(after: currentIndex, key: reviewKey(for: kanaCard))
        kanaCards.append(kanaCard)
    }

    func removeFutureKanaRepeats(after index: Int, key: String) {
        guard index + 1 < kanaCards.count else {
            return
        }

        for cardIndex in kanaCards.indices.reversed() where cardIndex > index && reviewKey(for: kanaCards[cardIndex]) == key {
            kanaCards.remove(at: cardIndex)
        }
    }

    func advanceToNextKanaOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            if startNextKanaPack() {
                return
            }

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

        let key = reviewKey(for: card)
        let answerID = currentSessionAnswerID()
        let existingAnswer = sessionAnswerStates[answerID]
        if let existingAnswer {
            restoreSessionAnswer(existingAnswer)
            removeFutureKanjiRepeats(after: currentIndex, key: key)
            rollbackFutureSessionAnswers(after: currentIndex)
        }

        var answerState = existingAnswer ?? SessionAnswerState(
            reviewKey: key,
            rating: rating,
            recordBefore: reviewStore.record(for: key),
            againCountBefore: kanjiAgainCounts[key],
            recoveryGoodCountBefore: kanjiRecoveryGoodCounts[key],
            wasMastered: masteredKanjiKeys.contains(card.kanji)
        )
        let wasReviewCard = reviewStore.record(for: key)?.state == .review
        let needsMoreRecovery = rating == .good && needsMoreRecoverySuccesses(for: key)
        let shouldUpdateSchedule = kanjiSessionPhase != .fallbackReview && !needsMoreRecovery
        let shouldResetIntervalOnGood = rating == .good && wasReviewCard && kanjiAgainCounts[key, default: 0] >= 2

        if shouldUpdateSchedule {
            reviewStore.apply(
                rating,
                to: key,
                learningSuccessTarget: kanjiLearningSuccessTarget,
                resetIntervalOnGood: shouldResetIntervalOnGood
            )
        }

        let reviewRecord = reviewStore.record(for: key)
        let isLearned = reviewRecord?.state == .review

        switch rating {
        case .again:
            masteredKanjiKeys.remove(card.kanji)
            kanjiAgainCounts[key, default: 0] += 1
            kanjiRecoveryGoodCounts[key] = 0
            scheduleKanjiRepeat(card, after: 2)
            if kanjiAgainCounts[key, default: 0] >= 3 {
                scheduleAdditionalKanjiRepeat(card, after: 5)
            }
        case .hard:
            masteredKanjiKeys.remove(card.kanji)
            scheduleKanjiRepeat(card, after: 5)
        case .good:
            if isLearned {
                if needsMoreRecovery {
                    masteredKanjiKeys.remove(card.kanji)
                    scheduleKanjiRepeatAtEnd(card)
                } else {
                    masteredKanjiKeys.insert(card.kanji)
                    kanjiAgainCounts[key] = nil
                    kanjiRecoveryGoodCounts[key] = nil
                    removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
                }
            } else {
                masteredKanjiKeys.remove(card.kanji)
                scheduleKanjiRepeatAtEnd(card)
            }
        }

        sessionCompletedCards = masteredKanjiKeys.count
        answerState.rating = rating
        sessionAnswerStates[answerID] = answerState
        if existingAnswer != nil {
            return
        }

        await advanceToNextKanjiOrFinish()
    }

    func restoreSessionAnswer(_ answer: SessionAnswerState) {
        reviewStore.restore(answer.recordBefore, for: answer.reviewKey)
        restoreCounter(answer.againCountBefore, for: answer.reviewKey, in: &kanjiAgainCounts)
        restoreCounter(answer.recoveryGoodCountBefore, for: answer.reviewKey, in: &kanjiRecoveryGoodCounts)

        switch practiceMode {
        case .kanji:
            if answer.wasMastered {
                masteredKanjiKeys.insert(answer.reviewKey)
            } else {
                masteredKanjiKeys.remove(answer.reviewKey)
            }
            sessionCompletedCards = masteredKanjiKeys.count
        case .words:
            if answer.wasMastered {
                masteredWordKeys.insert(answer.reviewKey)
            } else {
                masteredWordKeys.remove(answer.reviewKey)
            }
            sessionCompletedCards = masteredWordKeys.count
        case .kana:
            if answer.wasMastered {
                masteredKanaKeys.insert(answer.reviewKey)
            } else {
                masteredKanaKeys.remove(answer.reviewKey)
            }
            sessionCompletedCards = masteredKanaKeys.count
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

        let futureAnswers = sessionAnswerStates.compactMap { answerID, answer -> (String, Int, SessionAnswerState)? in
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
            sessionAnswerStates[answerID] = nil
        }
    }

    func removeFutureRepeatsForCurrentMode(after index: Int, key: String) {
        switch practiceMode {
        case .kanji:
            removeFutureKanjiRepeats(after: index, key: key)
        case .words:
            removeFutureWordRepeats(after: index, key: key)
        case .kana:
            removeFutureKanaRepeats(after: index, key: key)
        }
    }

    func clearFutureSessionAnswers(after index: Int) {
        let prefix = "\(practiceMode.rawValue):"
        let answerIDs = sessionAnswerStates.keys.filter { answerID in
            guard answerID.hasPrefix(prefix) else {
                return false
            }

            let indexText = answerID.dropFirst(prefix.count)
            return Int(indexText).map { $0 > index } ?? false
        }

        for answerID in answerIDs {
            sessionAnswerStates[answerID] = nil
        }
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

    func startNextWordPack() -> Bool {
        let sourceCards = !wordSourceCards.isEmpty ? wordSourceCards : previewWordCards
        guard !sourceCards.isEmpty, !isGuidedSingleKanjiPractice else {
            return false
        }

        let nextCards = nextWordSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        wordCards = nextCards
        cards.removeAll()
        kanaCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.id)).count)
        isPreparingCard = false
        resetCurrentAnswer()
        scrollToTopToken += 1
        return true
    }

    func startNextKanaPack() -> Bool {
        let sourceCards = !kanaSourceCards.isEmpty ? kanaSourceCards : previewKanaCards
        guard !sourceCards.isEmpty, !isGuidedSingleKanjiPractice else {
            return false
        }

        let nextCards = nextKanaSessionCards(from: sourceCards)
        guard !nextCards.isEmpty else {
            return false
        }

        kanaCards = nextCards
        cards.removeAll()
        wordCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        resetWordDrawingState()
        resetSessionProgress(total: Set(nextCards.map(\.character)).count)
        isPreparingCard = false
        resetCurrentAnswer()
        scrollToTopToken += 1
        return true
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
        wordSourceCards.removeAll()
        kanaSourceCards.removeAll()
        currentIndex = 0
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
        kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        isGuidedSingleKanjiPractice = false
        isPreparingCard = false
        hasStartedTraining = false
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        isKanjiPreviewPresented = false
        isKanaPreviewPresented = false
        isWordPreviewPresented = false
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
