import SwiftUI

extension ContentView {
    func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) {
        guard trainingSession.currentWordKanjiIndex < wordCard.kanjiCards.count else {
            return
        }

        saveCurrentWordDrawing()

        if trainingSession.currentWordKanjiIndex < wordCard.kanjiCards.count - 1 {
            trainingSession.currentWordKanjiIndex += 1
            trainingSession.drawnStrokes = trainingSession.completedWordDrawings[safe: trainingSession.currentWordKanjiIndex] ?? []
            trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[trainingSession.currentWordKanjiIndex])
            trainingSession.currentStroke.removeAll()
            return
        }

        trainingSession.wordFeedbackByKanji = evaluateWordParts(wordCard)
        trainingSession.feedback = flattenedWordFeedback(for: wordCard)
        withAnimation(.easeInOut(duration: 0.24)) {
            trainingSession.isAnswerVisible = true
        }
    }

    func selectWordKanji(at index: Int, in wordCard: WordStudyCard) {
        guard wordCard.kanjiCards.indices.contains(index) else {
            return
        }

        if !trainingSession.isAnswerVisible {
            saveCurrentWordDrawing()
        }

        trainingSession.currentWordKanjiIndex = index
        trainingSession.drawnStrokes = trainingSession.completedWordDrawings[safe: index] ?? []
        trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[index])
        trainingSession.currentStroke.removeAll()
    }

    var currentWordFeedback: [StrokeFeedback] {
        trainingSession.wordFeedbackByKanji[safe: trainingSession.currentWordKanjiIndex] ?? []
    }

    func saveCurrentWordDrawing() {
        while trainingSession.completedWordDrawings.count <= trainingSession.currentWordKanjiIndex {
            trainingSession.completedWordDrawings.append([])
        }

        trainingSession.completedWordDrawings[trainingSession.currentWordKanjiIndex] = trainingSession.drawnStrokes
    }

    func evaluateWordParts(_ wordCard: WordStudyCard) -> [[StrokeFeedback]] {
        wordCard.kanjiCards.indices.map { index in
            let strokes = index < trainingSession.completedWordDrawings.count ? trainingSession.completedWordDrawings[index] : []
            return StrokeEvaluator.evaluate(actual: strokes, expected: wordCard.kanjiCards[index].strokes)
        }
    }

    func flattenedWordFeedback(for wordCard: WordStudyCard) -> [StrokeFeedback] {
        trainingSession.wordFeedbackByKanji.enumerated().flatMap { index, items in
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

        return Array(card.strokes.prefix(min(trainingSession.guidedStrokeLimit, card.strokes.count)))
    }

    func expectedStrokesForCurrentCard(_ card: KanjiCard) -> [KanjiStroke] {
        guard trainingSession.isGuidedSingleKanjiPractice else {
            return trainingSession.isAnswerVisible ? card.strokes : []
        }

        return guidedExpectedStrokes(for: card)
    }

    func expectedStrokesForCurrentWordKanji(_ card: KanjiCard) -> [KanjiStroke] {
        trainingSession.isAnswerVisible ? card.strokes : []
    }

    func undoCurrentStroke(expected card: KanjiCard? = nil) {
        _ = trainingSession.drawnStrokes.popLast()
        trainingSession.feedback.removeAll()
        trainingSession.showsFeedbackInfo = false
        if let card {
            trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        }
        if trainingSession.isAnswerVisible {
            withAnimation(.easeInOut(duration: 0.18)) {
                trainingSession.isAnswerVisible = false
            }
        }
    }

    func clearCurrentDrawing(expected card: KanjiCard) {
        trainingSession.drawnStrokes.removeAll()
        trainingSession.currentStroke.removeAll()
        trainingSession.feedback.removeAll()
        trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        trainingSession.showsFeedbackInfo = false
        trainingSession.isAnswerVisible = false
    }

    func undoCurrentWordStroke(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        _ = trainingSession.drawnStrokes.popLast()
        storeCurrentWordFeedback([], in: wordCard)
        trainingSession.feedback = flattenedWordFeedback(for: wordCard)
        trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        trainingSession.showsFeedbackInfo = false
        if trainingSession.isAnswerVisible {
            withAnimation(.easeInOut(duration: 0.18)) {
                trainingSession.isAnswerVisible = false
            }
        }
    }

    func clearCurrentWordDrawing(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        trainingSession.drawnStrokes.removeAll()
        trainingSession.currentStroke.removeAll()
        storeCurrentWordFeedback([], in: wordCard)
        trainingSession.feedback = flattenedWordFeedback(for: wordCard)
        trainingSession.guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        trainingSession.showsFeedbackInfo = false
        trainingSession.isAnswerVisible = false
    }

    func nextGuidedStrokeLimit(for card: KanjiCard) -> Int {
        guard !card.strokes.isEmpty else {
            return 1
        }

        return min(max(trainingSession.drawnStrokes.count + 1, 1), card.strokes.count)
    }

    func handleGuidedStrokeFinished(_ card: KanjiCard) {
        guard trainingSession.isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            return
        }

        trainingSession.feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: trainingSession.drawnStrokes, expected: card.strokes)
        let latestSeverity = trainingSession.feedback.last { $0.strokeIndex == trainingSession.drawnStrokes.count - 1 }?.severity

        if latestSeverity == .good || latestSeverity == .minor {
            advanceGuidedStrokeOrReveal(card)
        }
    }

    func advanceGuidedStrokeOrReveal(_ card: KanjiCard) {
        guard trainingSession.isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            updateFeedback(for: card, reveal: true)
            return
        }

        if trainingSession.drawnStrokes.count >= card.strokes.count {
            updateFeedback(for: card, reveal: true)
            return
        }

        trainingSession.guidedStrokeLimit = min(max(trainingSession.guidedStrokeLimit + 1, trainingSession.drawnStrokes.count + 1), card.strokes.count)
    }


    func storeCurrentWordFeedback(_ items: [StrokeFeedback], in wordCard: WordStudyCard) {
        while trainingSession.wordFeedbackByKanji.count < wordCard.kanjiCards.count {
            trainingSession.wordFeedbackByKanji.append([])
        }

        trainingSession.wordFeedbackByKanji[trainingSession.currentWordKanjiIndex] = items
    }

}
