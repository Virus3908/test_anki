import CoreGraphics
import Foundation

@MainActor
@Observable
final class DrawingSessionViewModel {
    var currentWordKanjiIndex = 0
    var completedWordDrawings: [[[CGPoint]]] = []
    var wordFeedbackByKanji: [[StrokeFeedback]] = []
    var drawnStrokes: [[CGPoint]] = []
    var currentStroke: [CGPoint] = []
    var feedback: [StrokeFeedback] = []
    var guidedStrokeLimit = 1
    var showsFeedbackInfo = false
    var isAnswerVisible = false

    func resetWordDrawingState(resetKanjiIndex: Bool = true) {
        if resetKanjiIndex {
            currentWordKanjiIndex = 0
        }
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
    }

    func resetCurrentAnswer() {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        showsFeedbackInfo = false
        guidedStrokeLimit = 1
        isAnswerVisible = false
    }

    func guidedExpectedStrokes(for card: KanjiCard) -> [KanjiStroke] {
        guard !card.strokes.isEmpty else {
            return []
        }

        return Array(card.strokes.prefix(min(guidedStrokeLimit, card.strokes.count)))
    }

    func expectedStrokes(for card: KanjiCard, isGuided: Bool) -> [KanjiStroke] {
        guard isGuided else {
            return isAnswerVisible ? card.strokes : []
        }

        return guidedExpectedStrokes(for: card)
    }

    func expectedWordStrokes(for card: KanjiCard, isGuided: Bool) -> [KanjiStroke] {
        expectedStrokes(for: card, isGuided: isGuided)
    }

    func nextGuidedStrokeLimit(for card: KanjiCard) -> Int {
        guard !card.strokes.isEmpty else {
            return 1
        }

        return min(max(drawnStrokes.count + 1, 1), card.strokes.count)
    }

    func undoStroke(expected card: KanjiCard?) {
        _ = drawnStrokes.popLast()
        feedback.removeAll()
        showsFeedbackInfo = false
        if let card {
            guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        }
    }

    func clearDrawing(expected card: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        showsFeedbackInfo = false
//        isAnswerVisible = false
    }

    func evaluateFeedback(for card: KanjiCard, reveal: Bool) -> Bool {
        feedback = StrokeEvaluator.evaluate(actual: drawnStrokes, expected: card.strokes)
        return reveal
    }

    func handleGuidedStrokeFinished(_ card: KanjiCard, isGuided: Bool) -> Bool {
        guard isGuided, !card.strokes.isEmpty else {
            return false
        }

        feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: card.strokes)
        let latestSeverity = feedback.last { $0.strokeIndex == drawnStrokes.count - 1 }?.severity

        if latestSeverity == .good || latestSeverity == .minor {
            return advanceGuidedStrokeOrReveal(card, isGuided: isGuided)
        }

        return false
    }

    func advanceGuidedStrokeOrReveal(_ card: KanjiCard, isGuided: Bool) -> Bool {
        guard isGuided, !card.strokes.isEmpty else {
            return evaluateFeedback(for: card, reveal: true)
        }

        if drawnStrokes.count >= card.strokes.count {
            return evaluateFeedback(for: card, reveal: true)
        }

        guidedStrokeLimit = min(max(guidedStrokeLimit + 1, drawnStrokes.count + 1), card.strokes.count)
        return false
    }

    func revealAnswer() {
        isAnswerVisible = true
    }

    func hideAnswer() {
        isAnswerVisible = false
    }

    func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) -> Bool {
        guard currentWordKanjiIndex < wordCard.kanjiCards.count else {
            return false
        }

        saveCurrentWordDrawing()

        if currentWordKanjiIndex < wordCard.kanjiCards.count - 1 {
            currentWordKanjiIndex += 1
            drawnStrokes = completedWordDrawings[safe: currentWordKanjiIndex] ?? []
            guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[currentWordKanjiIndex])
            currentStroke.removeAll()
            return false
        }

        wordFeedbackByKanji = evaluateWordParts(wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        return true
    }

    func handleGuidedWordStrokeFinished(_ wordCard: WordStudyCard, isGuided: Bool) -> Bool {
        guard let currentKanji = wordCard.kanjiCards[safe: currentWordKanjiIndex] else {
            return false
        }

        let didFinishKanji = handleGuidedStrokeFinished(currentKanji, isGuided: isGuided)
        guard isGuided else {
            return false
        }

        storeCurrentWordFeedback(feedback, in: wordCard)
        guard didFinishKanji else {
            return false
        }

        let shouldReveal = advanceWordKanjiOrCheck(wordCard)
        if !shouldReveal {
            feedback = flattenedWordFeedback(for: wordCard)
        }
        return shouldReveal
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
            guard !wordCard.kanjiCards[index].strokes.isEmpty else { return [] }
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

    func undoCurrentWordStroke(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        _ = drawnStrokes.popLast()
        storeCurrentWordFeedback([], in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        showsFeedbackInfo = false
    }

    func clearCurrentWordDrawing(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        storeCurrentWordFeedback([], in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        showsFeedbackInfo = false
//        isAnswerVisible = false
    }

    func storeCurrentWordFeedback(_ items: [StrokeFeedback], in wordCard: WordStudyCard) {
        while wordFeedbackByKanji.count < wordCard.kanjiCards.count {
            wordFeedbackByKanji.append([])
        }

        wordFeedbackByKanji[currentWordKanjiIndex] = items
    }
}
