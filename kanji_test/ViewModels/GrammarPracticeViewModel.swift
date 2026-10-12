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
    let isFreePractice: Bool
    private(set) var isClosed = false
    let recallPrompts: [RecallPrompt]
    private(set) var position = 0
    private(set) var selectedOptionID: String?
    private(set) var isAnswerVisible = false
    private(set) var results: [GrammarExerciseResult] = []
    private let seed: String

    init(rule: GrammarRule, seed: String, freePractice: Bool = false) {
        self.rule = rule; self.seed = seed; isFreePractice = freePractice
        let available = rule.exercises ?? []
        exercises = available.allSatisfy { $0.isUsable(for: rule.id) }
            ? Array(GrammarExerciseSelection.ordered(available, seed: seed).prefix(3)) : []
        let examples = GrammarExerciseSelection.ordered(rule.examples, seed: seed + "examples")
        let example = examples.first ?? GrammarExample(ja: "", en: "", furigana: nil, ru: nil) // Loader requires at least one real source example.
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

    var isSelfAssessment: Bool { isFreePractice }
    var contentError: String? { !isFreePractice && exercises.count < 3 ? "Для этого правила пока нет трёх полноценных упражнений. Можно прочитать урок; результат обучения не будет сохранён." : nil }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var proposedRating: ReviewRating? { isComplete && !isSelfAssessment && !isClosed ? GrammarLessonRating.rating(correct: correctCount, total: count) : nil }
    func close() { isClosed = true }
    var count: Int { isSelfAssessment ? recallPrompts.count : exercises.count }
    var isComplete: Bool { contentError == nil && count > 0 && position >= count }
    var currentExercise: GrammarExercise? { exercises[safe: position] }
    var currentRecall: RecallPrompt? { recallPrompts[safe: position] }
    var options: [GrammarExercise.Option] {
        guard let exercise = currentExercise else { return [] }
        return GrammarExerciseSelection.ordered(exercise.options, seed: seed + exercise.id)
    }

    func choose(_ optionID: String) {
        guard !isClosed, contentError == nil, !isAnswerVisible, let exercise = currentExercise,
              exercise.options.contains(where: { $0.id == optionID }) else { return }
        selectedOptionID = optionID; isAnswerVisible = true
        results.append(GrammarExerciseResult(exerciseID: exercise.id, optionID: optionID, isCorrect: exercise.accepts(optionID)))
    }
    func reveal() { guard !isClosed, isSelfAssessment, !isComplete else { return }; isAnswerVisible = true }
    func next() {
        guard !isClosed, contentError == nil, isAnswerVisible, !isComplete else { return }
        position += 1; selectedOptionID = nil; isAnswerVisible = false
    }
}
