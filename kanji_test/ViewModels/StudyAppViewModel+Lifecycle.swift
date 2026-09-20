import Foundation

extension StudyAppViewModel {
    func loadSavedState() async {
        guard !hasLoadedSavedState, !isLoadingSavedState else { return }
        isLoadingSavedState = true
        do {
            try await trainingSession.loadProgress()
            hasLoadedSavedState = true
        } catch {
            errors.report("Не удалось загрузить прогресс. Исходный файл сохранён.", error: error)
        }
        isLoadingSavedState = false
        loadSupplementalState()
    }
    func restoreProgressBackup() async {
        do {
            try await trainingSession.restoreProgressBackup()
            hasLoadedSavedState = true
            synchronizeTrainingRoute()
            loadSupplementalState()
        } catch { errors.report("Не удалось восстановить резервную копию.", error: error) }
    }
    private func loadSupplementalState() {
        guard supplementalLoadTask == nil else { return }
        supplementalLoadTask = Task { [weak self] in
            guard let self else { return }
            defer { supplementalLoadTask = nil }
            async let translations: Void = translationState.loadSavedTranslations()
            async let library: Void = ankiLibrary.load()
            _ = await (translations, library)
        }
    }
    func advanceReviewDay() async {
        do { try await trainingSession.advanceStudyDay(); synchronizeTrainingRoute() }
        catch { errors.report("Не удалось сохранить новый учебный день.", error: error) }
    }
    func resume() async {
        await trainingSession.refreshForNewDay()
        synchronizeTrainingRoute()
    }
    func clearDeckCache() async {
        guard !isSavingReview else { return }
        trainingSession.finish()
        ankiLibrary.closeDeck()
        translationState.clearLoadedExamples()
        deckState.clearCacheState()
        coordinator.resetPreviewSelection()
        coordinator.clearRelatedWordState()
        catalog.clear()
        deckState.isLoadingDeck = true
        defer { deckState.isLoadingDeck = false }
        do {
            try await KanjiDataLoader.clearCache()
            try await KanaDataLoader.clearCache()
        } catch { errors.report("Не удалось очистить кэш.", error: error) }
    }
}
