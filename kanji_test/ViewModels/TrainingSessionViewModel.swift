import Foundation
import Observation
import AnkiImport

@MainActor
@Observable
final class TrainingSessionViewModel {
    private(set) var state = TrainingSessionState()
    private(set) var reviewStore = StudyProgressStore(records: [:])
    private(set) var isPreparingCard = false
    private(set) var hasLoadedProgress = false
    private(set) var canRestoreBackup = false
    let presentation = TrainingPresentation()
    var scrollToTopToken: Int { presentation.revision }
    /// Set only when the normal study queue for the day has been exhausted.
    /// The app uses this to return to the deck and present the completion sheet.
    private(set) var didCompleteToday = false
    private var addedNewCardsToday = 0
    private var addedNewCardsStudyDay: Date?
    private var addedNewCardsDeckID: String?
    var drawingSession: DrawingSessionViewModel { presentation.drawing }
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
    var currentAnkiCard: AnkiStudyCard? {
        guard mode == .anki, let id = queueIDs[safe: currentIndex] else { return nil }
        return catalog.anki(id)
    }
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
    /// Returns `nil` when review progress is not loaded yet (or a save is in flight) so the
    /// caller leaves the migration unmarked and retries later; `0` means nothing to migrate.
    func bootstrapAnkiHistory(_ collection: AnkiCollection, importID: String) async throws -> Int? {
        guard hasLoadedProgress, !isPreparingCard else { return nil }
        isPreparingCard = true
        defer { isPreparingCard = false }
        let options = Dictionary(uniqueKeysWithValues: collection.decks.map {
            ($0.id, settings.options(for: "anki:\(importID):deck:\($0.id)"))
        })
        let current = reviewStore
        let migrated = await Task.detached(priority: .userInitiated) {
            var progress = current
            let count = AnkiSchedulingMigrator.bootstrap(collection: collection, importID: importID,
                optionsByDeck: options, progress: &progress)
            return (progress, count)
        }.value
        guard migrated.1 > 0 else { return 0 }
        try await repository.save(migrated.0)
        reviewStore = migrated.0
        return migrated.1
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
    func resetProgress(for keys: Set<String>) async throws {
        guard hasLoadedProgress, !isPreparingCard else { throw CancellationError() }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var progress = reviewStore
        progress.resetProgress(for: keys)
        try await repository.save(progress)
        reviewStore = progress
        if let mode, state.queue.value?.sourceIDs.contains(where: { keys.contains(ReviewItem(id: $0, mode: mode).reviewKey) }) == true {
            didCompleteToday = false
            publish(TrainingSessionState())
        }
    }
    func deleteAnkiImportProgress(importID: String, deleteImport: () async throws -> Void) async throws {
        guard hasLoadedProgress, !isPreparingCard else { throw CancellationError() }
        isPreparingCard = true
        defer { isPreparingCard = false }
        let original = reviewStore
        var progress = original
        progress.removeAnkiImportProgress(importID: importID)
        try await repository.save(progress)
        do {
            try await deleteImport()
        } catch {
            try await repository.save(original)
            throw error
        }
        reviewStore = progress
        if mode == .anki { publish(TrainingSessionState()) }
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
    func excludeCurrentCard() async {
        guard hasLoadedProgress, !isPreparingCard, !isGuidedSingleKanjiPractice,
              let mode, let id = queueIDs[safe: currentIndex] else { return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var next = state
        var progress = reviewStore
        progress.exclude(ReviewItem(id: id, mode: mode).reviewKey)
        rebuild(&next, progress: progress)
        do {
            try await repository.save(progress)
            reviewStore = progress
            if next.todayIDs.isEmpty { finishCompletedToday() }
            else { publish(next) }
        } catch {
            errors.report("Не удалось исключить карточку из тренировки.", error: error)
        }
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
        next.rebuild(progress: progress,
            options: effectiveOptions(for: next.deck?.id, studyDay: progress.studyDate()), preferredID: preferredID)
    }
    @discardableResult
    private func markCurrentShown(in next: TrainingSessionState, progress: inout StudyProgressStore) -> Bool {
        next.markCurrentShown(progress: &progress)
    }
    func intervalLabel(for rating: ReviewRating) -> String {
        guard !isGuidedSingleKanjiPractice, let mode, let id = queueIDs[safe: currentIndex] else { return "" }
        let key = ReviewItem(id: id, mode: mode).reviewKey
        let now = reviewStore.studyDate()
        let next = try? StudyScheduler.record(after: rating, cardID: key, existingRecord: reviewStore.record(for: key), options: options, now: now)
        return TrainingPresentation.intervalLabel(next, now: now)
    }
    private func publish(_ next: TrainingSessionState) {
        state = next
        presentation.reset()
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
