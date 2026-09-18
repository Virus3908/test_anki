import Foundation
import Observation

@MainActor
@Observable
final class TrainingSessionViewModel {
    private(set) var state = TrainingSessionState()
    private(set) var reviewStore = StudyProgressStore(records: [:])
    private(set) var isPreparingCard = false
    private(set) var hasLoadedProgress = false
    private(set) var canRestoreBackup = false
    private(set) var scrollToTopToken = 0
    /// Set only when the normal study queue for the day has been exhausted.
    /// The app uses this to return to the deck and present the completion sheet.
    private(set) var didCompleteToday = false
    private var addedNewCardsToday = 0
    private var addedNewCardsStudyDay: Date?
    private var addedNewCardsDeckID: String?
    let drawingSession = DrawingSessionViewModel()
    private let repository: any ReviewPersisting
    private let catalog: StudyCardCatalog
    private let settings: StudyPreferences
    private let errors: StorageStatus

    init(repository: any ReviewPersisting, catalog: StudyCardCatalog, settings: StudyPreferences, errors: StorageStatus) {
        self.repository = repository
        self.catalog = catalog
        self.settings = settings
        self.errors = errors
    }
    var isActive: Bool { state.queue.mode != nil }
    var mode: PracticeMode? { state.queue.mode }
    var deck: StudyDeck? { state.deck }
    var options: DeckOptions { effectiveOptions(for: deck?.id) }
    var currentIndex: Int { state.currentIndex }
    var sessionTotalCards: Int { state.todayIDs.count }
    var sessionCompletedCards: Int { state.sessionCompletedCards }
    var isGuidedSingleKanjiPractice: Bool { state.isGuidedSingleKanjiPractice }
    var sessionAnswerStates: [String: SessionAnswerState] { state.sessionAnswerStates }
    var canGoBack: Bool { isGuidedSingleKanjiPractice ? currentIndex > 0 : !state.undoHistory.isEmpty }
    var canGoForward: Bool { isGuidedSingleKanjiPractice && currentIndex + 1 < queueIDs.count }
    var cards: [KanjiCard] { mode == .kanji ? queueIDs.compactMap(catalog.kanji) : [] }
    var wordCards: [WordStudyCard] { mode == .words ? queueIDs.compactMap(catalog.word) : [] }
    var kanaCards: [KanaStudyCard] { mode == .kana ? queueIDs.compactMap(catalog.kana) : [] }
    private var queueIDs: [String] { state.queue.value?.ids ?? [] }

    func loadProgress() async throws {
        guard !hasLoadedProgress else { return }
        do {
            reviewStore = try await repository.load()
            hasLoadedProgress = true
            canRestoreBackup = false
        } catch {
            canRestoreBackup = await repository.hasRecoverableBackup()
            throw error
        }
    }
    func restoreProgressBackup() async throws {
        guard !isPreparingCard else { return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        reviewStore = try await repository.restoreBackup()
        hasLoadedProgress = true
        canRestoreBackup = false
        publish(TrainingSessionState())
    }
    func start(deck: StudyDeck, sourceIDs: [String], guided: Bool = false) async -> Bool {
        guard hasLoadedProgress, !isPreparingCard else { return false }
        didCompleteToday = false
        isPreparingCard = true
        defer { isPreparingCard = false }
        var seen: Set<String> = []
        let source = sourceIDs.filter { seen.insert($0).inserted }
        guard !source.isEmpty else { return false }
        var next = TrainingSessionState()
        next.deck = deck
        next.queue = .make(mode: deck.mode, ids: source, sourceIDs: source)
        next.isGuidedSingleKanjiPractice = guided
        next.studyDay = reviewStore.studyDate()
        var progress = reviewStore
        if !guided { rebuild(&next, progress: progress) }
        do {
            if markCurrentShown(in: next, progress: &progress) { try await repository.save(progress) }
            reviewStore = progress
            if !guided, next.todayIDs.isEmpty { finishCompletedToday() }
            else { publish(next) }
            return true
        } catch {
            errors.report("Не удалось начать обучение. Прогресс не изменён.", error: error)
            return false
        }
    }
    func submitReview(_ rating: ReviewRating, expectedKey: String?) async {
        guard hasLoadedProgress, !isPreparingCard, let mode, let deck,
              let id = queueIDs[safe: currentIndex] else { return }
        if hasStudyDayChanged { await refreshForNewDay(); return }
        let key = ReviewItem(id: id, mode: mode).reviewKey
        guard expectedKey == nil || expectedKey == key else { return }
        if isGuidedSingleKanjiPractice {
            state.sessionAnswerStates[answerID(for: mode, index: currentIndex)] = SessionAnswerState(reviewKey: key, rating: rating)
            return
        }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var next = state
        var progress = reviewStore
        let previous = progress.record(for: key)
        do {
            let logID = try progress.apply(rating, to: key, deckID: deck.id, options: options)
            next.undoHistory.append(ReviewUndo(id: id, reviewKey: key, recordBefore: previous, logID: logID))
            next.sessionCompletedCards += 1
            rebuild(&next, progress: progress)
            _ = markCurrentShown(in: next, progress: &progress)
            try await repository.save(progress)
            reviewStore = progress
            if next.todayIDs.isEmpty { finishCompletedToday() }
            else { publish(next) }
        } catch { errors.report("Ответ не сохранён. Попробуй оценить карточку ещё раз.", error: error) }
    }
    func moveToPreviousCard() async {
        if isGuidedSingleKanjiPractice { moveInPractice(to: currentIndex - 1); return }
        guard !isPreparingCard, let undo = state.undoHistory.last else { return }
        if hasStudyDayChanged { await refreshForNewDay(); return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var progress = reviewStore
        progress.undo(logID: undo.logID, record: undo.recordBefore, key: undo.reviewKey)
        var next = state
        next.undoHistory.removeLast()
        next.sessionCompletedCards = max(0, next.sessionCompletedCards - 1)
        rebuild(&next, progress: progress, preferredID: undo.id)
        do {
            try await repository.save(progress)
            reviewStore = progress
            publish(next)
        } catch { errors.report("Не удалось отменить ответ.", error: error) }
    }
    func moveToNextCard() async {
        if isGuidedSingleKanjiPractice { moveInPractice(to: currentIndex + 1) }
    }
    private func moveInPractice(to index: Int) {
        guard !isPreparingCard, queueIDs.indices.contains(index) else { return }
        var next = state
        next.currentIndex = index
        publish(next)
    }
    func finish() {
        guard !isPreparingCard else { return }
        didCompleteToday = false
        publish(TrainingSessionState())
    }
    func addNewCardsToToday(_ count: Int, for deckID: String) {
        let today = reviewStore.studyDate()
        if addedNewCardsDeckID != deckID ||
            addedNewCardsStudyDay.map({ Calendar.current.isDate($0, inSameDayAs: today) }) != true {
            addedNewCardsToday = 0
            addedNewCardsStudyDay = today
            addedNewCardsDeckID = deckID
        }
        addedNewCardsToday = min(9999, addedNewCardsToday + max(1, count))
        didCompleteToday = false
    }
    func advanceStudyDay() async throws {
        guard hasLoadedProgress, !isPreparingCard else { return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var progress = reviewStore
        progress.advanceStudyDay()
        try await repository.save(progress)
        reviewStore = progress
        publish(TrainingSessionState())
    }
    private var hasStudyDayChanged: Bool {
        guard let day = state.studyDay else { return false }
        return !Calendar.current.isDate(day, inSameDayAs: reviewStore.studyDate())
    }
    func refreshForNewDay() async {
        guard isActive, !isPreparingCard, !isGuidedSingleKanjiPractice else { return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var next = state
        var progress = reviewStore
        let previousID = queueIDs[safe: currentIndex]
        if hasStudyDayChanged { next.undoHistory = []; next.sessionCompletedCards = 0 }
        rebuild(&next, progress: progress, preferredID: hasStudyDayChanged ? nil : previousID)
        do {
            if markCurrentShown(in: next, progress: &progress) { try await repository.save(progress) }
            reviewStore = progress
            if previousID == next.queue.value?.ids.first { state = next }
            else { publish(next) }
        } catch { errors.report("Не удалось обновить очередь обучения.", error: error) }
    }
    private func rebuild(_ next: inout TrainingSessionState, progress: StudyProgressStore, preferredID: String? = nil) {
        guard let queue = next.queue.value, let deck = next.deck else { return }
        let plan = TrainingSessionEngine.plan(sourceIDs: queue.sourceIDs, mode: deck.mode, deckID: deck.id,
            progress: progress, options: effectiveOptions(for: deck.id, studyDay: progress.studyDate()))
        var ids = plan.readyIDs
        if let preferredID, let index = ids.firstIndex(of: preferredID) { ids.remove(at: index); ids.insert(preferredID, at: 0) }
        next.replaceQueue(ids)
        next.todayIDs = plan.todayIDs
        next.currentIndex = 0
        next.studyDay = progress.studyDate()
        next.nextLearningDate = plan.nextLearningDate
        next.hiddenReviews = plan.hiddenReviews
    }
    @discardableResult
    private func markCurrentShown(in next: TrainingSessionState, progress: inout StudyProgressStore) -> Bool {
        guard !next.isGuidedSingleKanjiPractice, let mode = next.queue.mode,
              let id = next.queue.value?.ids[safe: next.currentIndex] else { return false }
        let key = ReviewItem(id: id, mode: mode).reviewKey
        let isNew = progress.records[key] == nil && progress.firstShownAt[key] == nil
        progress.markShown(key)
        return isNew
    }
    func intervalLabel(for rating: ReviewRating) -> String {
        guard !isGuidedSingleKanjiPractice, let mode, let id = queueIDs[safe: currentIndex] else { return "" }
        let key = ReviewItem(id: id, mode: mode).reviewKey
        let now = reviewStore.studyDate()
        guard let next = try? StudyScheduler.record(after: rating, cardID: key, existingRecord: reviewStore.record(for: key), options: options, now: now) else { return "—" }
        if next.intervalDays >= 1 { return "\(Int(next.intervalDays)) дн." }
        let minutes = max(1, Int(ceil(next.dueDate.timeIntervalSince(now) / 60)))
        return minutes < 60 ? "\(minutes) мин." : "\(minutes / 60) ч."
    }
    private func publish(_ next: TrainingSessionState) {
        state = next
        drawingSession.resetWordDrawingState()
        drawingSession.resetCurrentAnswer()
        scrollToTopToken += 1
    }
    private func finishCompletedToday() {
        didCompleteToday = true
        publish(TrainingSessionState())
    }
    private func effectiveOptions(for deckID: String?, studyDay: Date? = nil) -> DeckOptions {
        var result = settings.options(for: deckID)
        let day = studyDay ?? reviewStore.studyDate()
        guard addedNewCardsDeckID == deckID,
              addedNewCardsStudyDay.map({ Calendar.current.isDate($0, inSameDayAs: day) }) == true else {
            return result
        }
        result.dailyNewCardLimit = min(9999, result.dailyNewCardLimit + addedNewCardsToday)
        return result
    }
    func answerID(for mode: PracticeMode, index: Int) -> String { "\(mode.rawValue):\(index)" }
    func evaluateFeedback(for card: KanjiCard, reveal: Bool) -> Bool { drawingSession.evaluateFeedback(for: card, reveal: reveal) }
}
