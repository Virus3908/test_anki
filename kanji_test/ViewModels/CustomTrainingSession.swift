import Foundation
import Observation

/// Endless practice session over a user-selected subset of one deck.
///
/// Answers only reorder the in-session queue (Leitner-style reinsertion gaps):
/// nothing is persisted and the normal SRS day queue is never touched.
/// The queue never drains — every answered card is reinserted, so the session
/// runs until the user exits manually.
@MainActor
@Observable
final class CustomTrainingSession {
    private let catalog: StudyCardCatalog

    private(set) var deck: StudyDeck?
    private(set) var selectedIDs: Set<String> = []
    /// True while the deck preview screen is in card selection mode.
    private(set) var isSelecting = false
    /// Upcoming card IDs; the first element is the current card.
    private(set) var queue: [String] = []
    private(set) var isAnswerVisible = false
    private var strength: [String: Int] = [:]

    private(set) var answersCount = 0
    private(set) var correctCount = 0
    private(set) var currentStreak = 0
    private(set) var bestStreak = 0
    private(set) var round = 0
    private var seenThisRound: Set<String> = []

    init(catalog: StudyCardCatalog) {
        self.catalog = catalog
    }

    var isRunning: Bool { !queue.isEmpty }
    var currentID: String? { queue.first }
    var accuracy: Double {
        guard answersCount > 0 else { return 0 }
        return Double(correctCount) / Double(answersCount)
    }

    var currentKanjiCard: KanjiCard? {
        guard deck?.mode == .kanji, let id = currentID else { return nil }
        return catalog.kanji(id)
    }
    var currentWordCard: WordStudyCard? {
        guard deck?.mode == .words, let id = currentID else { return nil }
        return catalog.word(id)
    }
    var currentKanaCard: KanaStudyCard? {
        guard deck?.mode == .kana, let id = currentID else { return nil }
        return catalog.kana(id)
    }
    var currentAnkiCard: AnkiStudyCard? {
        guard deck?.mode == .anki, let id = currentID else { return nil }
        return catalog.anki(id)
    }

    func setSelection(_ ids: Set<String>) {
        selectedIDs = ids
    }

    func toggle(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    /// Turns the open deck preview into card selection mode.
    func beginSelection() {
        isSelecting = true
    }

    /// Leaves selection mode and drops the pending selection.
    func cancelSelection() {
        isSelecting = false
        selectedIDs = []
    }

    /// Leaves selection mode, keeping the picked IDs (used when training starts).
    func finishSelection() {
        isSelecting = false
    }

    func start(deck: StudyDeck, cardIDs: [String]) {
        guard !cardIDs.isEmpty else { return }
        self.deck = deck
        selectedIDs = Set(cardIDs)
        strength.removeAll()
        queue = cardIDs.shuffled()
        isAnswerVisible = false
        answersCount = 0
        correctCount = 0
        currentStreak = 0
        bestStreak = 0
        round = 1
        seenThisRound = []
        markSeenIfNeeded()
    }

    func revealAnswer() {
        isAnswerVisible = true
    }

    func submit(_ rating: ReviewRating) {
        guard let cardID = queue.first else { return }
        recordStats(for: rating)
        let box = updatedBox(for: cardID, rating: rating)
        strength[cardID] = box
        queue.removeFirst()
        queue.insert(cardID, at: min(reinsertionGap(box: box), queue.count))
        isAnswerVisible = false
        markSeenIfNeeded()
    }

    func stop() {
        queue = []
        isAnswerVisible = false
    }

    // MARK: - Queue mechanics

    private func recordStats(for rating: ReviewRating) {
        answersCount += 1
        let isCorrect = rating != .again
        if isCorrect {
            correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
    }

    private func updatedBox(for cardID: String, rating: ReviewRating) -> Int {
        let box = strength[cardID] ?? 0
        let result: Int
        switch rating {
        case .again: result = 0
        case .hard: result = max(1, box)
        case .good: result = box + 1
        case .easy: result = box + 2
        }
        return min(result, maxStrengthBox)
    }

    /// How many other cards pass before the card returns, based on its box.
    private func reinsertionGap(box: Int) -> Int {
        box == 0 ? nearMissGap : baseGap * (1 << max(0, box - 1))
    }

    /// A round completes once every selected card has been seen since the last completion.
    private func markSeenIfNeeded() {
        guard let current = queue.first else { return }
        if seenThisRound.count >= selectedIDs.count {
            round += 1
            seenThisRound = []
        }
        seenThisRound.insert(current)
    }

    private let nearMissGap = 2
    private let baseGap = 4
    private let maxStrengthBox = 8
}
