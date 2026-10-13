import Foundation

/// Free input is limited to a single unambiguous verb form, with kanji/kana alternatives.
/// Sentences continue using explicitly authored keys/orders, never fuzzy semantic matching.
nonisolated enum GrammarAnswerValidator {
    static func accepts(_ text: String, for exercise: GrammarExercise) -> Bool {
        if exercise.kind == .restoreSentence {
            guard exercise.isUsable(for: exercise.ruleID), exercise.isScored == false else { return false }
            return text.trimmingCharacters(in: .whitespacesAndNewlines) == exercise.correctAnswer
        }
        guard exercise.kind == .formProduction, exercise.validConjugation,
              let task = exercise.conjugation,
              let answer = GrammarConjugationEngine.conjugate(task.verb, to: task.form) else { return false }
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        }
        return [answer.text, answer.reading].map(normalized).contains(normalized(text))
    }
}
