import Foundation
import Observation

/// One passage produces one explicit FSRS rating for the rule, never one per question.
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
    let exercises: [GrammarExercise]
    let recallPrompts: [RecallPrompt]
    private(set) var position = 0
    private(set) var selectedOptionID: String?
    private(set) var isAnswerVisible = false
    private(set) var results: [GrammarExerciseResult] = []
    private let seed: String

    init(rule: GrammarRule, seed: String) {
        self.rule = rule; self.seed = seed
        exercises = GrammarExerciseSelection.ordered(rule.exercises ?? [], seed: seed)
        let examples = GrammarExerciseSelection.ordered(rule.examples, seed: seed + "examples")
        let example = examples[0] // Loader requires at least one real source example.
        let prompts = [
            RecallPrompt(id: "\(rule.id):recall-meaning", question: "Объясни значение и контекст употребления конструкции.",
                cue: rule.pattern, sourceAnswer: [rule.displayedMeaning, rule.displayedExplanation ?? ""].joined(separator: "\n\n")),
            RecallPrompt(id: "\(rule.id):recall-formation", question: "Вспомни формулу образования: какая форма предшествует конструкции?",
                cue: rule.pattern, sourceAnswer: rule.displayedFormation),
            RecallPrompt(id: "\(rule.id):recall-example", question: "Переведи пример и объясни роль конструкции в предложении.",
                cue: example.ja, sourceAnswer: example.ru ?? example.en)
        ]
        recallPrompts = GrammarExerciseSelection.ordered(prompts, seed: seed + "recall")
    }

    var isSelfAssessment: Bool { exercises.isEmpty }
    var count: Int { isSelfAssessment ? recallPrompts.count : exercises.count }
    var isComplete: Bool { position >= count }
    var currentExercise: GrammarExercise? { exercises[safe: position] }
    var currentRecall: RecallPrompt? { recallPrompts[safe: position] }
    var options: [GrammarExercise.Option] {
        guard let exercise = currentExercise else { return [] }
        return GrammarExerciseSelection.ordered(exercise.options, seed: seed + exercise.id)
    }

    func choose(_ optionID: String) {
        guard !isAnswerVisible, let exercise = currentExercise,
              exercise.options.contains(where: { $0.id == optionID }) else { return }
        selectedOptionID = optionID; isAnswerVisible = true
        results.append(GrammarExerciseResult(exerciseID: exercise.id, optionID: optionID, isCorrect: exercise.accepts(optionID)))
    }
    func reveal() { guard isSelfAssessment, !isComplete else { return }; isAnswerVisible = true }
    func next() {
        guard isAnswerVisible, !isComplete else { return }
        position += 1; selectedOptionID = nil; isAnswerVisible = false
    }
}
