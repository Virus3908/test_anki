import Foundation

@MainActor
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
    var drawingSession = DrawingSessionViewModel()
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

    func prepareStudyPack<Item: StudyItem>(
        _ items: [Item],
        guided: Bool? = nil,
        scrollToTop: Bool = false
    ) {
        resetQueuePosition()
        resetWordDrawingState()
        resetSessionProgress(total: TrainingSessionEngine.uniqueReviewItemCount(items))
        if let guided {
            isGuidedSingleKanjiPractice = guided
        }
        isPreparingCard = false
        resetCurrentAnswer()
        if scrollToTop {
            requestScrollToTop()
        }
    }

    func answerID(for mode: PracticeMode, index: Int) -> String {
        "\(mode.rawValue):\(index)"
    }

    func currentAnswerID(for mode: PracticeMode) -> String {
        answerID(for: mode, index: currentIndex)
    }

    func moveToNextCard(resetWordDrawing: Bool = false) {
        currentIndex += 1
        if resetWordDrawing {
            resetWordDrawingState()
        }
        resetCurrentAnswer()
        requestScrollToTop()
    }

    func moveToPreviousCard() {
        currentIndex -= 1
        resetWordDrawingState()
        resetCurrentAnswer()
        requestScrollToTop()
    }

    func moveToCard(at index: Int) {
        currentIndex = index
        resetCurrentAnswer()
        requestScrollToTop()
    }

    func resetFinishedSession() {
        resetQueuePosition()
        kanjiSessionPhase = .learning
        resetWordDrawingState()
        resetSessionProgress(total: 0)
        isGuidedSingleKanjiPractice = false
        isPreparingCard = false
        resetCurrentAnswer()
    }

    func resetWordDrawingState(resetKanjiIndex: Bool = true) {
        drawingSession.resetWordDrawingState(resetKanjiIndex: resetKanjiIndex)
    }

    func resetCurrentAnswer() {
        drawingSession.resetCurrentAnswer()
    }

    func requestScrollToTop() {
        scrollToTopToken += 1
    }
}
