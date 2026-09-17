import Foundation

struct StudyQueue {
    var ids: [String]
    let sourceIDs: [String]
}

enum ActiveStudyQueue {
    case idle
    case kanji(StudyQueue)
    case words(StudyQueue)
    case kana(StudyQueue)

    var mode: PracticeMode? {
        switch self {
        case .idle: return nil
        case .kanji: return .kanji
        case .words: return .words
        case .kana: return .kana
        }
    }
    var value: StudyQueue? {
        switch self {
        case .idle: return nil
        case .kanji(let value), .words(let value), .kana(let value): return value
        }
    }
    static func make(mode: PracticeMode, ids: [String], sourceIDs: [String]) -> Self {
        let value = StudyQueue(ids: ids, sourceIDs: sourceIDs)
        switch mode {
        case .kanji: return .kanji(value)
        case .words: return .words(value)
        case .kana: return .kana(value)
        }
    }
}

struct TrainingSessionState {
    var queue: ActiveStudyQueue = .idle
    var currentIndex = 0
    var sessionTotalCards = 0
    var sessionCompletedCards = 0
    var masteredKeys: Set<String> = []
    var isGuidedSingleKanjiPractice = false
    var kanjiAgainCounts: [String: Int] = [:]
    var kanjiRecoveryGoodCounts: [String: Int] = [:]
    var sessionAnswerStates: [String: SessionAnswerState] = [:]
    var kanjiSessionPhase: KanjiLearningSessionPhase = .learning
    var studyDay: Date?

    func currentAnswerID(for mode: PracticeMode) -> String { "\(mode.rawValue):\(currentIndex)" }
    mutating func replaceQueue(_ ids: [String]) {
        guard let mode = queue.mode, let source = queue.value?.sourceIDs else { return }
        queue = .make(mode: mode, ids: ids, sourceIDs: source)
    }
}

struct ReviewItem: StudyItem {
    let id: String
    let mode: PracticeMode
    nonisolated var reviewKey: String {
        switch mode {
        case .kanji: return id
        case .words: return "word:\(id)"
        case .kana: return "kana:\(id)"
        }
    }
}
