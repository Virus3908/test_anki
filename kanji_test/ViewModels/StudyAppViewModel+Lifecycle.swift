import Foundation

extension StudyAppViewModel {
    func loadSavedState() async {
        guard !hasLoadedSavedState, !isLoadingSavedState else { return }
        isLoadingSavedState = true
        defer { isLoadingSavedState = false }
        do {
            try await trainingSession.loadProgress()
            await translationState.loadSavedTranslations()
            await ankiLibrary.load()
            hasLoadedSavedState = true
        } catch {
            errors.report("Не удалось загрузить прогресс. Исходный файл сохранён.", error: error)
        }
    }
    func restoreProgressBackup() async {
        do {
            try await trainingSession.restoreProgressBackup()
            await translationState.loadSavedTranslations()
            hasLoadedSavedState = true
            synchronizeTrainingRoute()
        } catch { errors.report("Не удалось восстановить резервную копию.", error: error) }
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
        translationState.clearLoadedExamples()
        deckState.clearCacheState()
        coordinator.resetPreviewSelection()
        catalog.clear()
        deckState.isLoadingDeck = true
        defer { deckState.isLoadingDeck = false }
        do {
            try await KanjiDataLoader.clearCache()
            try await KanaDataLoader.clearCache()
        } catch { errors.report("Не удалось очистить кэш.", error: error) }
    }
}
