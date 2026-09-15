import SwiftUI

extension ContentView {
    func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) {
        guard currentWordKanjiIndex < wordCard.kanjiCards.count else {
            return
        }

        saveCurrentWordDrawing()

        if currentWordKanjiIndex < wordCard.kanjiCards.count - 1 {
            currentWordKanjiIndex += 1
            drawnStrokes = completedWordDrawings[safe: currentWordKanjiIndex] ?? []
            guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[currentWordKanjiIndex])
            currentStroke.removeAll()
            return
        }

        wordFeedbackByKanji = evaluateWordParts(wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        withAnimation(.easeInOut(duration: 0.24)) {
            isAnswerVisible = true
        }
    }

    func selectWordKanji(at index: Int, in wordCard: WordStudyCard) {
        guard wordCard.kanjiCards.indices.contains(index) else {
            return
        }

        if !isAnswerVisible {
            saveCurrentWordDrawing()
        }

        currentWordKanjiIndex = index
        drawnStrokes = completedWordDrawings[safe: index] ?? []
        guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[index])
        currentStroke.removeAll()
    }

    var currentWordFeedback: [StrokeFeedback] {
        wordFeedbackByKanji[safe: currentWordKanjiIndex] ?? []
    }

    func saveCurrentWordDrawing() {
        while completedWordDrawings.count <= currentWordKanjiIndex {
            completedWordDrawings.append([])
        }

        completedWordDrawings[currentWordKanjiIndex] = drawnStrokes
    }

    func evaluateWordParts(_ wordCard: WordStudyCard) -> [[StrokeFeedback]] {
        wordCard.kanjiCards.indices.map { index in
            let strokes = index < completedWordDrawings.count ? completedWordDrawings[index] : []
            return StrokeEvaluator.evaluate(actual: strokes, expected: wordCard.kanjiCards[index].strokes)
        }
    }

    func flattenedWordFeedback(for wordCard: WordStudyCard) -> [StrokeFeedback] {
        wordFeedbackByKanji.enumerated().flatMap { index, items in
            items.map { item in
                StrokeFeedback(
                    strokeIndex: nil,
                    severity: item.severity,
                    message: "\(wordCard.kanjiCards[index].kanji): \(item.message)"
                )
            }
        }
    }

    func kanjiCard(for kanaCard: KanaStudyCard) -> KanjiCard {
        KanjiCard(
            kanji: kanaCard.character,
            meanings: [kanaCard.reading],
            onyomi: [],
            kunyomi: [kanaCard.reading],
            examples: [],
            source: KanjiSource(name: "KanjiVG", file: "kana", license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"),
            strokes: kanaCard.strokes,
            translationState: "ru-system"
        )
    }

    func guidedExpectedStrokes(for card: KanjiCard) -> [KanjiStroke] {
        guard !card.strokes.isEmpty else {
            return []
        }

        return Array(card.strokes.prefix(min(guidedStrokeLimit, card.strokes.count)))
    }

    func expectedStrokesForCurrentCard(_ card: KanjiCard) -> [KanjiStroke] {
        guard isGuidedSingleKanjiPractice else {
            return isAnswerVisible || !feedback.isEmpty ? card.strokes : []
        }

        return guidedExpectedStrokes(for: card)
    }

    func expectedStrokesForCurrentWordKanji(_ card: KanjiCard) -> [KanjiStroke] {
        isAnswerVisible || !currentWordFeedback.isEmpty ? card.strokes : []
    }

    func undoCurrentStroke() {
        _ = drawnStrokes.popLast()
    }

    func clearCurrentDrawing(expected card: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        showsFeedbackInfo = false
    }

    func undoCurrentWordStroke(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        _ = drawnStrokes.popLast()
        let currentFeedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: currentKanji.strokes)
        storeCurrentWordFeedback(currentFeedback, in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
    }

    func clearCurrentWordDrawing(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        storeCurrentWordFeedback([], in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        showsFeedbackInfo = false
    }

    func nextGuidedStrokeLimit(for card: KanjiCard) -> Int {
        guard !card.strokes.isEmpty else {
            return 1
        }

        return min(max(drawnStrokes.count + 1, 1), card.strokes.count)
    }

    func handleGuidedStrokeFinished(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            return
        }

        feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: card.strokes)
        let latestSeverity = feedback.last { $0.strokeIndex == drawnStrokes.count - 1 }?.severity

        if latestSeverity == .good || latestSeverity == .minor {
            advanceGuidedStrokeOrReveal(card)
        }
    }

    func advanceGuidedStrokeOrReveal(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            updateFeedback(for: card, reveal: true)
            return
        }

        if drawnStrokes.count >= card.strokes.count {
            updateFeedback(for: card, reveal: true)
            return
        }

        guidedStrokeLimit = min(max(guidedStrokeLimit + 1, drawnStrokes.count + 1), card.strokes.count)
    }


    func storeCurrentWordFeedback(_ items: [StrokeFeedback], in wordCard: WordStudyCard) {
        while wordFeedbackByKanji.count < wordCard.kanjiCards.count {
            wordFeedbackByKanji.append([])
        }

        wordFeedbackByKanji[currentWordKanjiIndex] = items
    }

}
