import Foundation
import Observation

/// Transient lesson state. Scheduling and persistence belong to the shared session.
@MainActor
@Observable
final class GrammarPracticeViewModel {
    nonisolated struct RecallPrompt: Identifiable, Sendable {
        let id: String
        let question: String
        let cue: String
        let sourceAnswer: String
    }
    let rule: GrammarRule
    private(set) var exercises: [GrammarExercise]
    let isFreePractice: Bool
    let isReview: Bool
    let attempt: Int
    let recallPrompts: [RecallPrompt]
    private(set) var isClosed = false
    private(set) var position = 0
    private(set) var selectedOptionID: String?
    private(set) var selectedElements: [String] = []
    private(set) var isAnswerVisible = false
    private(set) var usedHint = false
    private(set) var results: [GrammarExerciseResult] = []
    private(set) var isSaving = false
    private(set) var isSaved = false
    var isLessonRead: Bool
    private let seed: String
    private var reserve: [GrammarExercise]
    private var remediationCount = 0
    private let previousRating: ReviewRating?
    static let maximumCount = 8

    init(rule: GrammarRule, seed: String, freePractice: Bool = false, isReview: Bool = false, attempt: Int = 0,
         previousRating: ReviewRating? = nil) {
        self.rule = rule; self.seed = seed; self.attempt = attempt
        isFreePractice = freePractice; self.isReview = isReview; isLessonRead = isReview
        self.previousRating = previousRating
        var seen = Set<String>()
        let available = GrammarExerciseSelection.ordered(rule.exercises ?? [], seed: seed).filter {
            $0.isUsable(for: rule.id) && $0.eligibleForPractice
                && seen.insert($0.promptRU + "\n" + ($0.japanese ?? "")).inserted
        }
        let complexity = min(3, max(1, rule.teaching?.complexity ?? 2))
        let target = isReview ? min(5, 2 + complexity + (previousRating == .again ? 1 : 0)) : min(6, 3 + complexity)
        // First encounter scaffolds formation before independent application.
        // Reviews rotate within comparable difficulty, starting at the learner's level.
        let ordered = available.enumerated().sorted { a, b in
            let preferred = isReview ? min(3, 1 + attempt / 2) : 1
            let da = abs(a.element.difficulty - preferred)
            let db = abs(b.element.difficulty - preferred)
            if da != db { return da < db }
            if !isReview {
                let pa = Self.stage(a.element.kind), pb = Self.stage(b.element.kind)
                if pa != pb { return pa < pb }
            }
            return a.offset < b.offset
        }.map(\.element)
        // Keep more than one skill in the initial lesson, even with easy formation tasks.
        var initial: [GrammarExercise] = []
        let independent: [GrammarExerciseKind] = [.understandSentence, .correctError, .distinguishMeaning]
        let kinds: [GrammarExerciseKind] = isReview
            ? GrammarExerciseSelection.ordered([.fillBlank, .chooseContext, .transformSentence, .assembleSentence] + independent, seed: seed + "skills")
            : [.fillBlank, .chooseContext, .transformSentence, .assembleSentence]
                + GrammarExerciseSelection.ordered(independent, seed: seed + "skills")
        for kind in kinds {
            if let exercise = ordered.first(where: { $0.kind == kind }), initial.count < target {
                initial.append(exercise)
            }
        }
        for exercise in ordered where initial.count < target && !initial.contains(where: { $0.id == exercise.id }) {
            initial.append(exercise)
        }
        exercises = initial.sorted { Self.stage($0.kind) < Self.stage($1.kind) }
        let selected = Set(initial.map(\.id))
        reserve = ordered.filter { !selected.contains($0.id) }
        let example = rule.examples.first ?? GrammarExample(ja: "", en: "", furigana: nil, ru: nil)
        recallPrompts = [
            RecallPrompt(id: "\(rule.id):meaning", question: "Объясни смысл в контексте.", cue: rule.pattern, sourceAnswer: rule.displayedMeaning),
            RecallPrompt(id: "\(rule.id):formation", question: "Вспомни образование.", cue: rule.pattern, sourceAnswer: rule.displayedFormation),
            RecallPrompt(id: "\(rule.id):example", question: "Объясни смысл предложения.", cue: example.ja, sourceAnswer: example.ru ?? example.en)
        ]
    }

    private static func stage(_ kind: GrammarExerciseKind) -> Int {
        switch kind {
        case .fillBlank: 0
        case .chooseContext, .understandSentence: 1
        case .transformSentence: 2
        case .assembleSentence: 3
        case .correctError, .distinguishMeaning: 4
        default: 5
        }
    }
    var isSelfAssessment: Bool { isFreePractice }
    var contentError: String? {
        !isFreePractice && exercises.count < 3 ? "Практика для этого правила ещё готовится. Все объяснения и примеры доступны." : nil
    }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var proposedRating: ReviewRating? {
        isComplete && !isSelfAssessment && !isClosed && !isSaved
            ? GrammarLessonRating.rating(correct: correctCount, total: count, hints: results.filter(\.usedHint).count) : nil
    }
    var weakAspects: [String] {
        var seen = Set<String>()
        return results.filter { !$0.isCorrect || $0.usedHint }.compactMap { result in
            guard let exercise = exercises.first(where: { $0.id == result.exerciseID }),
                  let aspect = exercise.aspect, seen.insert(aspect).inserted else { return nil }
            return aspect
        }
    }
    func close() { isClosed = true }
    func beginSaving() -> ReviewRating? {
        guard !isSaving, let rating = proposedRating else { return nil }
        isSaving = true
        return rating
    }
    func finishSaving(success: Bool) { isSaving = false; isSaved = success }
    var count: Int { isSelfAssessment ? recallPrompts.count : exercises.count }
    var isComplete: Bool { contentError == nil && count > 0 && position >= count }
    var currentExercise: GrammarExercise? { exercises[safe: position] }
    var currentRecall: RecallPrompt? { recallPrompts[safe: position] }
    var options: [GrammarExercise.Option] {
        guard let exercise = currentExercise else { return [] }
        return GrammarExerciseSelection.ordered(exercise.options, seed: seed + exercise.id)
    }

    func useHint() {
        guard !isClosed, !isComplete, !isAnswerVisible, contentError == nil else { return }
        usedHint = true
    }
    func choose(_ optionID: String) {
        guard !isClosed, contentError == nil, !isAnswerVisible, let exercise = currentExercise,
              exercise.kind != .assembleSentence, exercise.options.contains(where: { $0.id == optionID }) else { return }
        selectedOptionID = optionID
        record(correct: exercise.accepts(optionID), answer: optionID)
    }
    func toggleElement(_ id: String) {
        guard !isClosed, !isAnswerVisible, currentExercise?.kind == .assembleSentence,
              options.contains(where: { $0.id == id }) else { return }
        if let index = selectedElements.firstIndex(of: id) { selectedElements.remove(at: index) }
        else { selectedElements.append(id) }
    }
    func checkAssembly() {
        guard !isClosed, !isAnswerVisible, contentError == nil, let exercise = currentExercise,
              exercise.kind == .assembleSentence, !selectedElements.isEmpty else { return }
        record(correct: exercise.accepts(order: selectedElements), answer: selectedElements.joined(separator: "|"))
    }
    private func record(correct: Bool, answer: String) {
        guard let exercise = currentExercise else { return }
        isAnswerVisible = true
        results.append(GrammarExerciseResult(exerciseID: exercise.id, optionID: answer, isCorrect: correct, usedHint: usedHint))
        if (!correct || usedHint), remediationCount < 2, exercises.count < Self.maximumCount,
           let index = reserve.firstIndex(where: { $0.aspect == exercise.aspect && $0.aspect != nil }) {
            // Another context for the same skill; no repeated question, no unbounded extension.
            exercises.insert(reserve.remove(at: index), at: position + 1)
            remediationCount += 1
        }
        if isReview, previousRating != .again, results.count >= 3,
           results.allSatisfy({ $0.isCorrect && !$0.usedHint }) {
            let answered = Set(results.compactMap { result in exercises.first { $0.id == result.exerciseID }?.kind })
            let formation = !answered.isDisjoint(with: [.fillBlank, .transformSentence, .correctError])
            let context = !answered.isDisjoint(with: [.chooseContext, .understandSentence, .distinguishMeaning])
            let application = !answered.isDisjoint(with: [.transformSentence, .assembleSentence])
            if formation && context && application { exercises = Array(exercises.prefix(position + 1)) }
        }
    }
    func reveal() { guard !isClosed, isSelfAssessment, !isComplete else { return }; isAnswerVisible = true }
    func next() {
        guard !isClosed, contentError == nil, isAnswerVisible, !isComplete else { return }
        position += 1; selectedOptionID = nil; selectedElements = []; isAnswerVisible = false; usedHint = false
    }
}
