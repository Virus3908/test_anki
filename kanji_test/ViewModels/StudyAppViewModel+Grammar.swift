import Foundation

extension StudyAppViewModel {
    /// Free rule selection uses the same planner and daily grants as sequential study.
    /// Review-only starts from already introduced rules, including learning/relearning.
    func startGrammar(_ level: GrammarLevel, ruleID: String? = nil, reviewsOnly: Bool = false) {
        guard !isSavingReview, !deckState.isLoadingDeck else { return }
        trainingStartTask?.cancel()
        trainingStartTask = Task { [weak self] in
            guard let self else { return }
            defer { trainingStartTask = nil }
            do {
                let rules = try await GrammarDataLoader.shared.rules(level)
                try Task.checkCancellation()
                let source = rules.filter { rule in
                    if let ruleID { return rule.id == ruleID }
                    if reviewsOnly {
                        return self.trainingSession.reviewStore.record(for: rule.reviewKey) != nil
                            || self.trainingSession.reviewStore.firstShownAt[rule.reviewKey] != nil
                    }
                    return true
                }
                guard !source.isEmpty else {
                    errors.message = reviewsOnly ? "Пока нет изученных правил для повторения." : "Правило не найдено."
                    return
                }
                let started = await trainingSession.start(deck: level.deck, sourceIDs: catalog.register(source))
                guard started else { return }
                if navigation.deckRoute.deck?.id != level.deck.id { navigation.open(.grammarLevel(level)) }
                if trainingSession.isActive { navigation.beginTraining(.grammar) }
                else if trainingSession.didCompleteToday { isTodayCompletionPresented = true }
            } catch is CancellationError { }
            catch { errors.report("Не удалось загрузить грамматику.", error: error) }
        }
    }
}
