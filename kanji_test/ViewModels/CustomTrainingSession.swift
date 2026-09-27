import Foundation
import Observation

/// Endless practice session over a user-selected subset of one deck.
///
/// Answers only reorder the in-session queue: a repeat never overtakes
/// cards not yet shown in the current round, and Leitner-style gaps order
/// the repeats once the round is covered. Nothing is persisted and the
/// normal SRS day queue is never touched. The queue never drains — every
/// answered card is reinserted, so the session runs until the user exits.
@MainActor
@Observable
final class CustomTrainingSession {
    private let catalog: StudyCardCatalog
    private let settings: StudyPreferences

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
    /// День, в котором стартовала сессия: тип карточки и дистракторы теста
    /// детерминированы от него и не «прыгают» при перестановке очереди.
    private(set) var studyDay = Date()

    init(catalog: StudyCardCatalog, settings: StudyPreferences) {
        self.catalog = catalog
        self.settings = settings
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

    /// Тип текущей карточки: детерминированный от дня старта сессии, поэтому
    /// переживает перестановку очереди. Anki в кастом-режиме — свой экран.
    var currentCardType: TrainingCardType {
        guard let deck, deck.mode != .anki, let id = currentID else { return .drawing }
        return TrainingCardType.resolve(
            cardID: id,
            deckID: deck.id,
            date: studyDay,
            allowed: TrainingCardType.effectiveTypes(configured: settings.options(for: deck.id).cardTypes, mode: deck.mode)
        )
    }

    /// Значения остальных выбранных карточек — пул дистракторов для теста.
    func recallMeaningPool(excluding cardID: String) -> [String] {
        guard let mode = deck?.mode else { return [] }
        return selectedIDs.filter { $0 != cardID }.sorted().compactMap { id -> [String]? in
            switch mode {
            case .kanji: return catalog.kanji(id)?.meanings
            case .words:
                guard let meaning = catalog.word(id)?.meaning, !meaning.isEmpty else { return nil }
                return [meaning]
            case .kana:
                guard let reading = catalog.kana(id)?.reading, !reading.isEmpty else { return nil }
                return [reading]
            case .anki: return nil
            }
        }.flatMap { $0 }
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
        studyDay = Date()
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
        queue.insert(cardID, at: reinsertionIndex(box: box))
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

    /// Slot the answered card returns to.
    ///
    /// A repeat must never overtake a card not yet shown in the current
    /// round: until the whole selection has passed, repeats queue up behind
    /// the unseen remainder. Front-anchored gaps alone starve large
    /// selections — short-gap reinsertions (test/typed answers emit
    /// "again"/"hard") rotate a ~5-card window at the head while the rest
    /// of the queue never advances. The Leitner gap takes over only for
    /// the repeat ordering once no unseen cards are left in the round.
    private func reinsertionIndex(box: Int) -> Int {
        let firstRepeatSlot = (queue.lastIndex { !seenThisRound.contains($0) } ?? -1) + 1
        return min(max(reinsertionGap(box: box), firstRepeatSlot), queue.count)
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
