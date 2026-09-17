import Foundation
import Observation

/// Sole owner of active training, progress and introduction accounting.
@MainActor
@Observable
final class TrainingSessionViewModel {
    private(set) var state = TrainingSessionState()
    private(set) var reviewStore = KanjiReviewStore(records: [:])
    private(set) var isPreparingCard = false
    private(set) var hasLoadedProgress = false
    private(set) var canRestoreBackup = false
    private(set) var scrollToTopToken = 0
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
    var currentIndex: Int { state.currentIndex }
    var sessionTotalCards: Int { state.sessionTotalCards }
    var sessionCompletedCards: Int { state.sessionCompletedCards }
    var isGuidedSingleKanjiPractice: Bool { state.isGuidedSingleKanjiPractice }
    var sessionAnswerStates: [String: SessionAnswerState] { state.sessionAnswerStates }
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

    func start(mode: PracticeMode, sourceIDs: [String], guided: Bool = false) async -> Bool {
        guard hasLoadedProgress, !isPreparingCard else { return false }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var progress = reviewStore
        var next = makePack(mode: mode, sourceIDs: sourceIDs, progress: progress, guided: guided)
        guard next.queue.mode != nil else {
            errors.message = "На сегодня всё готово: повторений нет, новые карточки закончились или дневной лимит достигнут."
            return false
        }
        do {
            if markCurrentShown(in: &next, progress: &progress) { try await repository.save(progress) }
            reviewStore = progress
            publish(next)
            return true
        } catch {
            errors.report("Не удалось начать обучение. Прогресс не изменён.", error: error)
            return false
        }
    }

    func submitReview(_ rating: ReviewRating, expectedKey: String?) async {
        guard hasLoadedProgress, !isPreparingCard, let mode else { return }
        if hasStudyDayChanged { await refreshForNewDay(); return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var next = state
        var progress = reviewStore
        var items = queueIDs.map { ReviewItem(id: $0, mode: mode) }
        guard let item = items[safe: currentIndex], expectedKey == nil || item.reviewKey == expectedKey else { return }
        let shouldAdvance = TrainingReviewService.applyReview(item: item, rating: rating, mode: mode,
            session: &next, reviewStore: &progress, items: &items, learningSuccessTarget: settings.learningSuccessTarget)
        next.replaceQueue(items.map(\.id))
        if shouldAdvance {
            if next.sessionCompletedCards >= next.sessionTotalCards {
                next = makePack(mode: mode, sourceIDs: next.queue.value?.sourceIDs ?? [], progress: progress)
            } else if next.currentIndex + 1 < items.count {
                next.currentIndex += 1
            }
        }
        _ = markCurrentShown(in: &next, progress: &progress)
        do {
            if !state.isGuidedSingleKanjiPractice { try await repository.save(progress) }
            reviewStore = progress
            if shouldAdvance { publish(next) } else { state = next }
        } catch {
            errors.report("Ответ не сохранён. Попробуй оценить карточку ещё раз.", error: error)
        }
    }

    func moveToPreviousCard() async { await move(to: currentIndex - 1) }
    func moveToNextCard() async { await move(to: currentIndex + 1) }

    private func move(to index: Int) async {
        guard !isPreparingCard, queueIDs.indices.contains(index) else { return }
        if hasStudyDayChanged { await refreshForNewDay(); return }
        isPreparingCard = true
        defer { isPreparingCard = false }
        var next = state
        var progress = reviewStore
        next.currentIndex = index
        do {
            if markCurrentShown(in: &next, progress: &progress) { try await repository.save(progress) }
            reviewStore = progress
            publish(next)
        } catch {
            errors.report("Не удалось сохранить показ карточки.", error: error)
        }
    }

    func finish() {
        guard !isPreparingCard else { return }
        publish(TrainingSessionState())
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
        guard !isPreparingCard, let mode, hasStudyDayChanged,
              let source = state.queue.value?.sourceIDs else { return }
        if makePack(mode: mode, sourceIDs: source, progress: reviewStore,
                    guided: state.isGuidedSingleKanjiPractice).queue.mode == nil {
            finish()
            return
        }
        _ = await start(mode: mode, sourceIDs: source, guided: state.isGuidedSingleKanjiPractice)
    }

    private func makePack(mode: PracticeMode, sourceIDs: [String], progress: KanjiReviewStore, guided: Bool = false) -> TrainingSessionState {
        var seen: Set<String> = []
        let source = sourceIDs.filter { seen.insert($0).inserted }
        let items = source.map { ReviewItem(id: $0, mode: mode) }
        let selection = guided ? (items: items, phase: KanjiLearningSessionPhase.fallbackReview) :
            TrainingSessionEngine.nextSessionItems(from: items, reviewStore: progress,
                newCardLimit: settings.dailyNewCardLimit, learningSuccessTarget: settings.learningSuccessTarget)
        guard !selection.items.isEmpty else { return TrainingSessionState() }
        var next = TrainingSessionState()
        next.queue = .make(mode: mode, ids: selection.items.map(\.id), sourceIDs: source)
        next.sessionTotalCards = selection.items.count
        next.kanjiSessionPhase = selection.phase
        next.isGuidedSingleKanjiPractice = guided
        next.studyDay = progress.studyDate()
        return next
    }

    /// Persist only actual introductions, not every card preselected for a pack.
    @discardableResult
    private func markCurrentShown(in next: inout TrainingSessionState, progress: inout KanjiReviewStore) -> Bool {
        guard !next.isGuidedSingleKanjiPractice, let mode = next.queue.mode,
              let ids = next.queue.value?.ids else { return false }
        var available = progress.remainingNewCards(limit: settings.dailyNewCardLimit)
        var retained: [String] = []
        for (index, id) in ids.enumerated() {
            let key = ReviewItem(id: id, mode: mode).reviewKey
            let introduced = progress.records[key] != nil || progress.firstShownAt[key] != nil
            if index < next.currentIndex || introduced { retained.append(id) }
            else if available > 0 { retained.append(id); available -= 1 }
        }
        next.replaceQueue(retained)
        next.sessionTotalCards = Set(retained).count
        guard let id = retained[safe: next.currentIndex] else {
            next = TrainingSessionState()
            return false
        }
        let key = ReviewItem(id: id, mode: mode).reviewKey
        let isNew = progress.records[key] == nil && progress.firstShownAt[key] == nil
        progress.markShown(key)
        return isNew
    }

    private func publish(_ next: TrainingSessionState) {
        state = next
        drawingSession.resetWordDrawingState()
        drawingSession.resetCurrentAnswer()
        scrollToTopToken += 1
    }

    func answerID(for mode: PracticeMode, index: Int) -> String { "\(mode.rawValue):\(index)" }
    func evaluateFeedback(for card: KanjiCard, reveal: Bool) -> Bool { drawingSession.evaluateFeedback(for: card, reveal: reveal) }
}
