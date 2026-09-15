import CoreGraphics
import Foundation

@Observable
final class TrainingSessionViewModel {
    var isPreparingCard = false
    var currentIndex = 0
    var sessionTotalCards = 0
    var sessionCompletedCards = 0
    var masteredKanjiKeys: Set<String> = []
    var masteredWordKeys: Set<String> = []
    var masteredKanaKeys: Set<String> = []
    var isGuidedSingleKanjiPractice = false
    var kanjiAgainCounts: [String: Int] = [:]
    var kanjiRecoveryGoodCounts: [String: Int] = [:]
    var sessionAnswerStates: [String: SessionAnswerState] = [:]
    var kanjiSessionPhase: KanjiLearningSessionPhase = .learning
    var currentWordKanjiIndex = 0
    var completedWordDrawings: [[[CGPoint]]] = []
    var wordFeedbackByKanji: [[StrokeFeedback]] = []
    var drawnStrokes: [[CGPoint]] = []
    var currentStroke: [CGPoint] = []
    var feedback: [StrokeFeedback] = []
    var guidedStrokeLimit = 1
    var showsFeedbackInfo = false
    var isAnswerVisible = false
    var scrollToTopToken = 0

    func resetSessionProgress(total: Int) {
        sessionTotalCards = total
        sessionCompletedCards = 0
        masteredKanjiKeys.removeAll()
        masteredWordKeys.removeAll()
        masteredKanaKeys.removeAll()
        sessionAnswerStates.removeAll()
    }

    func resetReviewCounters() {
        kanjiAgainCounts.removeAll()
        kanjiRecoveryGoodCounts.removeAll()
    }

    func resetQueuePosition() {
        currentIndex = 0
        resetReviewCounters()
    }

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
}
