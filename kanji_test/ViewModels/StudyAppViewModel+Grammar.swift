import Foundation

extension StudyAppViewModel {
    /// Free rule selection uses the same planner and daily grants as sequential study.
    /// Review-only starts from already introduced rules, including learning/relearning.
    func startGrammar(_ level: GrammarLevel, ruleID: String? = nil, reviewsOnly: Bool = false) {
        if ruleID == nil {
            startMixedGrammar(levels: [level], scope: reviewsOnly ? .studied : .mixed)
            return
        }
        guard !isSavingReview, !deckState.isLoadingDeck else { return }
        trainingStartTask?.cancel()
        trainingStartTask = Task { [weak self] in
            guard let self else { return }
            defer { trainingStartTask = nil }
            do {
                let rules = try await GrammarDataLoader.shared.rules(level)
                try Task.checkCancellation()
                var source = rules.filter { rule in
                    guard rule.teaching != nil,
                          (rule.exercises ?? []).filter({ $0.eligibleForPractice && $0.isUsable(for: rule.id) }).count >= 3 else { return false }
                    if reviewsOnly {
                        return self.trainingSession.reviewStore.record(for: rule.reviewKey) != nil
                            || self.trainingSession.reviewStore.firstShownAt[rule.reviewKey] != nil
                    }
                    return true
                }
                if let ruleID {
                    guard let index = source.firstIndex(where: { $0.id == ruleID }) else {
                        errors.message = "Практика для этого правила ещё готовится. Объяснение и примеры доступны."
                        return
                    }
                    source = [source[index]]
                }
                guard !source.isEmpty else {
                    errors.message = reviewsOnly ? "Пока нет изученных правил для повторения." : "Практика этого уровня ещё готовится."
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
    func startMixedGrammar(levels: Set<GrammarLevel>, scope: GrammarSessionPlanner.Scope = .mixed) {
        guard !isSavingReview, !deckState.isLoadingDeck, !levels.isEmpty else { return }
        trainingStartTask?.cancel()
        trainingStartTask = Task { [weak self] in
            guard let self else { return }
            defer { trainingStartTask = nil }
            do {
                let rules = try await GrammarDataLoader.shared.allRules()
                try Task.checkCancellation()
                _ = catalog.register(rules)
                let started = await trainingSession.startMixedGrammar(rules: rules, levels: levels, scope: scope)
                guard started else {
                    errors.message = "В выбранной области сейчас нет доступных правил с подготовленной практикой. Проверь расписание и дневные лимиты."
                    return
                }
                navigation.beginTraining(.grammar)
            } catch is CancellationError { }
            catch { errors.report("Не удалось начать смешанную тренировку.", error: error) }
        }
    }
}
