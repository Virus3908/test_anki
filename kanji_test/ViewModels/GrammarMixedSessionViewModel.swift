import Foundation
import Observation

/// One bounded attempt per rule, retaining existing lesson validation/adaptation.
@MainActor @Observable
final class GrammarMixedSessionViewModel {
    let levels: Set<GrammarLevel>
    let scope: GrammarSessionPlanner.Scope
    let studyDay: Date
    let sourceIDs: [String]
    let practices: [GrammarPracticeViewModel]
    private(set) var currentRuleID: String?
    private(set) var history: [String] = []
    private(set) var completedExerciseIDs: [String] = []
    private(set) var revision = 0
    private var lastSteps: [String: Int] = [:]
    private var retryAfter: [String: Int] = [:]
    private let priorities: [String: Int]
    private let seed: String
    private let previouslyStudied: Set<String>

    init(candidates: [GrammarSessionPlanner.Candidate], levels: Set<GrammarLevel>, scope: GrammarSessionPlanner.Scope,
         progress: StudyProgressStore, seed: String) {
        self.levels = levels; self.scope = scope; studyDay = progress.studyDate(); self.seed = seed
        let known = Set(progress.records.keys.filter { $0.hasPrefix("grammar:") }.map { String($0.dropFirst(8)) })
        previouslyStudied = known
        let possible = known.union(candidates.map { $0.rule.id })
        sourceIDs = candidates.map { $0.rule.id }
        priorities = Dictionary(uniqueKeysWithValues: candidates.map { ($0.rule.id, $0.priority) })
        practices = candidates.map { candidate in
            let rule = candidate.rule
            // Standalone comparison scaffolds reveal the target construction. In mixed practice,
            // only context/application questions whose alternatives were taught are used.
            let material = rule.withExercises((rule.exercises ?? []).filter {
                $0.kind != .distinguishMeaning && Set($0.requiredRuleIDs ?? []).isSubset(of: possible)
            })
            let record = progress.record(for: rule.reviewKey)
            return GrammarPracticeViewModel(rule: material, seed: seed + rule.id, isReview: record != nil,
                attempt: record?.attempts ?? 0, previousRating: record?.lastRating)
        }
        currentRuleID = candidates.first?.rule.id
    }
    var current: GrammarPracticeViewModel? { practices.first { $0.rule.id == currentRuleID } }
    var isComplete: Bool { practices.allSatisfy(\.isComplete) }
    var total: Int { practices.reduce(0) { $0 + $1.count } }
    var answered: Int { practices.reduce(0) { $0 + $1.results.count } }
    var correct: Int { practices.reduce(0) { $0 + $1.correctCount } }
    var basicCompletedRules: Int { practices.filter { $0.isComplete && $0.exercises.allSatisfy { $0.isScored == false } }.count }
    var savedRules: Int { practices.filter(\.isSaved).count }
    var newRules: Int { practices.filter { $0.isSaved && !$0.isReview }.count }
    var repeatedRules: Int { practices.filter { $0.isSaved && $0.isReview }.count }
    var weakRules: [GrammarRule] { practices.filter { !$0.weakAspects.isEmpty }.map(\.rule) }
    var hasUnsavedResults: Bool { practices.contains { $0.isComplete && !$0.isSaved && $0.proposedRating != nil } }

    func advance() {
        guard let current, current.isAnswerVisible else { return }
        let id = current.rule.id
        let previousSentenceID = current.currentExercise?.sentenceID
        if let result = current.results.last {
            completedExerciseIDs.append(result.exerciseID)
            if !result.isCorrect || result.usedHint { retryAfter[id] = history.count + 3 }
            else { retryAfter[id] = nil }
        }
        history.append(id); lastSteps[id] = history.count - 1
        current.next()
        let introduced = previouslyStudied.union(practices.filter { $0.isLessonRead && !$0.results.isEmpty }.map { $0.rule.id })
        let active = practices.filter {
            !$0.isComplete && $0.contentError == nil
                && Set($0.currentExercise?.requiredRuleIDs ?? []).isSubset(of: introduced)
        }.map {
            GrammarSessionPlanner.ActiveRule(id: $0.rule.id, priority: priorities[$0.rule.id] ?? 2,
                lastStep: lastSteps[$0.rule.id] ?? -1, retryAfter: retryAfter[$0.rule.id], hasErrors: !$0.weakAspects.isEmpty,
                sentenceID: $0.currentExercise?.sentenceID)
        }
        currentRuleID = GrammarSessionPlanner.nextRule(active, previousID: id, step: history.count, seed: seed,
            previousSentenceID: previousSentenceID)
        revision += 1
    }
    func restartAfterUndo(ruleID: String) {
        // Restart that attempt using the same pool, with no carryover of an already scored result.
        practices.first { $0.rule.id == ruleID }?.restartAttempt()
        currentRuleID = ruleID; retryAfter[ruleID] = nil
        revision += 1
    }
}
