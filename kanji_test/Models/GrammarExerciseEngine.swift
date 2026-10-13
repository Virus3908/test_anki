import Foundation

/// Pure lesson planning; no UI, persistence, singleton or scheduling.
nonisolated enum GrammarExerciseEngine {
    struct Plan: Sendable { let exercises: [GrammarExercise]; let reserve: [GrammarExercise] }
    static let maximumCount = 8
    static func plan(rule: GrammarRule, seed: String, isReview: Bool, attempt: Int, previousRating: ReviewRating?) -> Plan {
        var seen = Set<String>()
        let available = GrammarExerciseSelection.ordered(rule.exercises ?? [], seed: seed).filter {
            $0.isUsable(for: rule.id) && $0.eligibleForPractice
                && seen.insert($0.promptRU + "\n" + ($0.japanese ?? "")).inserted
        }
        let complexity = min(3, max(1, rule.teaching?.complexity ?? 2))
        let hasProduction = available.contains { $0.kind == .formProduction }
        let target = isReview ? min(4, 2 + complexity + (previousRating == .again ? 1 : 0))
            : min(6, 3 + complexity + (hasProduction ? 1 : 0))
        // First encounter scaffolds formation before independent application.
        // Reviews rotate within comparable difficulty, starting at the learner's level.
        let ordered = available.enumerated().sorted { a, b in
            let preferred = isReview && previousRating != .again ? min(previousRating == .hard ? 2 : 3, 1 + attempt / 2) : 1
            let da = abs(a.element.difficulty - preferred)
            let db = abs(b.element.difficulty - preferred)
            if da != db { return da < db }
            if !isReview {
                let pa = stage(a.element.kind), pb = stage(b.element.kind)
                if pa != pb { return pa < pb }
            }
            return a.offset < b.offset
        }.map(\.element)
        // Keep more than one skill in the initial lesson, even with easy formation tasks.
        var initial: [GrammarExercise] = []
        if isReview {
            for group in [[GrammarExerciseKind.formProduction, .fillBlank, .correctError],
                [.chooseContext, .understandSentence, .distinguishMeaning], [.transformSentence, .assembleSentence]] {
                if let exercise = ordered.first(where: { group.contains($0.kind) }) {
                    initial.append(exercise)
                }
            }
        }
        let independent: [GrammarExerciseKind] = [.understandSentence, .correctError, .distinguishMeaning]
        let kinds: [GrammarExerciseKind] = isReview
            ? GrammarExerciseSelection.ordered([.formProduction, .fillBlank, .chooseContext, .transformSentence, .assembleSentence] + independent, seed: seed + "skills")
            : [.formProduction, .fillBlank, .chooseContext, .transformSentence, .assembleSentence]
                + GrammarExerciseSelection.ordered(independent, seed: seed + "skills")
        for kind in kinds {
            if let exercise = ordered.first(where: { $0.kind == kind }), initial.count < target,
               !initial.contains(where: { $0.id == exercise.id }) {
                initial.append(exercise)
            }
        }
        for exercise in ordered where initial.count < target && !initial.contains(where: { $0.id == exercise.id }) {
            initial.append(exercise)
        }
        let selectedExercises = isReview ? initial : initial.sorted { stage($0.kind) < stage($1.kind) }
        let selected = Set(initial.map(\.id))
        let reserve = ordered.filter { !selected.contains($0.id) }
        return Plan(exercises: selectedExercises, reserve: reserve)
    }
    static func stage(_ kind: GrammarExerciseKind) -> Int {
        switch kind {
        case .formProduction, .fillBlank: 0
        case .chooseContext, .understandSentence: 1
        case .transformSentence: 2
        case .assembleSentence: 3
        case .correctError, .distinguishMeaning: 4
        default: 5
        }
    }
}
