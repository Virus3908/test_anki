import Foundation

/// Exercise interleaving over the existing FSRS queue; never computes review intervals.
nonisolated enum GrammarSessionPlanner {
    enum Scope: String, Sendable { case mixed, newRules, studied }
    struct Candidate: Sendable {
        let rule: GrammarRule
        let priority: Int
    }
    static let maximumRules = 4

    static func candidates(rules: [GrammarRule], levels: Set<GrammarLevel>, scope: Scope,
                           progress: StudyProgressStore, options: [GrammarLevel: DeckOptions],
                           now: Date = Date()) -> [Candidate] {
        var result: [Candidate] = []
        for level in GrammarLevel.allCases where levels.contains(level) {
            let available = rules.filter { rule in
                guard rule.level == level, GrammarExerciseEngine.availableExercises(for: rule).contains(where: { $0.kind != .distinguishMeaning }) else { return false }
                let introduced = progress.record(for: rule.reviewKey) != nil || progress.firstShownAt[rule.reviewKey] != nil
                return scope == .mixed || (scope == .studied ? introduced : !introduced)
            }
            let plan = TrainingSessionEngine.plan(sourceIDs: available.map(\.id), mode: .grammar,
                deckID: level.deck.id, progress: progress, options: options[level] ?? DeckOptions(), now: now)
            for id in plan.readyIDs {
                guard let rule = available.first(where: { $0.id == id }) else { continue }
                let record = progress.record(for: rule.reviewKey)
                let priority = record.map { $0.state == .review ? 1 : 0 } ?? 2
                result.append(Candidate(rule: rule, priority: priority))
            }
        }
        // Preserve the shared queue's learning/review/new policy across selected decks.
        return Array(result.enumerated().sorted { a, b in
            if a.element.priority != b.element.priority { return a.element.priority < b.element.priority }
            let da = progress.record(for: a.element.rule.reviewKey)?.dueDate ?? .distantFuture
            let db = progress.record(for: b.element.rule.reviewKey)?.dueDate ?? .distantFuture
            return da == db ? a.offset < b.offset : da < db
        }.prefix(maximumRules).map(\.element))
    }

    struct ActiveRule: Sendable {
        let id: String
        let priority: Int
        let lastStep: Int
        let retryAfter: Int?
        let hasErrors: Bool
        var sentenceID: String? = nil
    }
    static func nextRule(_ active: [ActiveRule], previousID: String?, step: Int, seed: String,
                         previousSentenceID: String? = nil) -> String? {
        guard !active.isEmpty else { return nil }
        let cooled = active.filter { ($0.retryAfter ?? 0) <= step }
        let ready = cooled.isEmpty ? active : cooled
        let freshContext = ready.filter { $0.sentenceID == nil || $0.sentenceID != previousSentenceID }
        let pool = freshContext.isEmpty ? ready : freshContext
        let alternatives = pool.filter { $0.id != previousID }
        let choices = GrammarExerciseSelection.ordered(alternatives.isEmpty ? pool : alternatives, seed: seed + ":\(step)")
        return choices.sorted { a, b in
            // A due remediation wins only after other questions have created spacing.
            let ar = a.hasErrors && a.retryAfter != nil && a.retryAfter! <= step
            let br = b.hasErrors && b.retryAfter != nil && b.retryAfter! <= step
            if ar != br { return ar }
            if a.lastStep != b.lastStep { return a.lastStep < b.lastStep }
            return a.priority < b.priority
        }.first?.id
    }
}
