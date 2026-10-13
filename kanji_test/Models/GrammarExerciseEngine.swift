import Foundation

/// Pure lesson planning; no UI, persistence, singleton or scheduling.
nonisolated enum GrammarExerciseEngine {
    struct Plan: Sendable { let exercises: [GrammarExercise]; let reserve: [GrammarExercise] }
    static let maximumCount = 8
    static func plan(rule: GrammarRule, seed: String, isReview: Bool, attempt: Int, previousRating: ReviewRating?) -> Plan {
        var seen = Set<String>()
        var seenSentences = Set<String>()
        let available = GrammarExerciseSelection.ordered(availableExercises(for: rule), seed: seed).filter {
            $0.isUsable(for: rule.id) && ($0.eligibleForPractice || $0.kind == .restoreSentence)
                && seen.insert($0.promptRU + "\n" + ($0.kind == .restoreSentence ? $0.correctAnswer : ($0.japanese ?? ""))).inserted
                && ($0.sentenceID.map { seenSentences.insert($0).inserted } ?? true)
        }
        let complexity = min(3, max(1, rule.teaching?.complexity ?? 2))
        // Attempts come from the existing review record. Rotate contexts within a skill,
        // independently of changing presentation seeds; never write a synthetic review.
        var rotationRank: [String: Int] = [:]
        for kind in GrammarExerciseKind.allCases {
            for difficulty in 1...3 {
                let group = available.filter { $0.kind == kind && $0.difficulty == difficulty }
                    .sorted { ($0.sentenceID ?? $0.id) < ($1.sentenceID ?? $1.id) }
                for (index, exercise) in group.enumerated() {
                    rotationRank[exercise.id] = (index - max(0, attempt) % group.count + group.count) % group.count
                }
            }
        }
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
            if rotationRank[a.element.id] != rotationRank[b.element.id] {
                return (rotationRank[a.element.id] ?? 0) < (rotationRank[b.element.id] ?? 0)
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
    /// Exact-source recall only: no inferred grammar, distractors, segmentation or semantic rating.
    static func basicExercises(for rule: GrammarRule) -> [GrammarExercise] {
        var seen = Set<String>()
        return rule.examples.enumerated().compactMap { index, example in
            guard !example.ja.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !example.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seen.insert(example.ja).inserted else { return nil }
            var exercise = GrammarExercise(id: "\(rule.id):source:\(index):restore", ruleID: rule.id,
                kind: .restoreSentence,
                promptRU: "Восстанови исходный пример по памяти. Здесь проверяется именно исходная фраза, а не свободный перевод. Можно посмотреть её в подсказке.",
                options: [.init(id: "source", text: example.ja, feedbackRU: nil)], acceptedOptionIDs: ["source"],
                explanationRU: "Ответ отличается от исходного примера. Другая формулировка может быть грамматически верной: это задание её не оценивает. Сравни с оригиналом и восстанови его.",
                difficulty: 1, cueEN: example.ru ?? example.en,
                provenance: .init(commit: "0d1d3410bec90bd4098a7c72de820543cb4f707c", sourceRuleID: rule.id, exampleIndex: index,
                    method: "Exact original example restoration; no linguistic review", status: .structurallyChecked),
                aspect: "Восстановление исходного примера", hintRU: example.ja, isScored: false)
            exercise.sentenceID = rule.exampleReferences?[safe: index]?.sentenceID
            // Keep existing verified source markup through the shared renderer.
            if let ruby = example.ruby, let markup = ruby.transcriptions?.first?.text {
                exercise.furigana = [example.ja: markup]
            }
            return exercise.isUsable(for: rule.id) ? exercise : nil
        }
    }
    static func availableExercises(for rule: GrammarRule) -> [GrammarExercise] {
        let extended = (rule.exercises ?? []).filter { $0.isUsable(for: rule.id) && $0.eligibleForPractice }
        return extended.isEmpty ? basicExercises(for: rule) : extended
    }
    static func hasPractice(_ rule: GrammarRule) -> Bool { !availableExercises(for: rule).isEmpty }
    static func hasExtendedPractice(_ rule: GrammarRule) -> Bool {
        (rule.exercises ?? []).contains { $0.eligibleForPractice && $0.isUsable(for: rule.id) }
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
