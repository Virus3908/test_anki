import Foundation
import AnkiImport

extension StudyAppViewModel {
    func resetDeckProgress(_ deck: StudyDeck) async {
        guard hasLoadedSavedState, !isSavingReview else { return }
        isResettingDeckProgress = true
        defer { isResettingDeckProgress = false }
        do {
            let keys: Set<String>
            switch deck.mode {
            case .kanji:
                guard let selected = KanjiDeck(rawValue: String(deck.id.dropFirst("kanji:".count))) else { return }
                keys = Set(await KanjiDataLoader.loadAvailableCards(deck: selected).map(\.reviewKey))
            case .words:
                guard let selected = WordFrequencyDeck(rawValue: String(deck.id.dropFirst("words:".count))) else { return }
                let entries = try await WordDataLoader.loadDictionaryEntries()
                keys = Set(entries[selected.bounds.clamped(to: entries.indices)].map { "word:\($0.word)-\($0.reading)" })
            case .kana:
                guard let selected = KanaDeck(rawValue: String(deck.id.dropFirst("kana:".count))) else { return }
                keys = Set(selected.baseCards.map(\.reviewKey))
            case .anki:
                guard let reference = ankiLibrary.decks.first(where: { $0.id == deck.id }),
                      let summary = ankiLibrary.imports.first(where: { $0.id == reference.importID }) else { return }
                let (collection, _) = try await ankiLibrary.open(summary)
                keys = Set(collection.cards.filter { $0.deckID == reference.sourceDeckID }
                    .map { "anki:\(reference.importID):card:\($0.id)" })
            }
            guard !keys.isEmpty else {
                errors.message = "Не удалось найти карточки выбранной колоды. Прогресс не изменён."
                return
            }
            try await trainingSession.resetProgress(for: keys)
            synchronizeTrainingRoute()
        } catch {
            errors.report("Не удалось сбросить прогресс колоды. Данные не изменены.", error: error)
        }
    }

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
