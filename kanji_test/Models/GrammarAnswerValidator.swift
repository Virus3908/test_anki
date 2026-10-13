import Foundation

/// Only explicit keys and deterministic forms are accepted. Similarity is never evidence.
nonisolated enum GrammarAnswerValidator {
    enum Assessment: String, Codable, Sendable {
        case correct, differsFromSample, incorrectForm
    }

    static func accepts(_ text: String, for exercise: GrammarExercise) -> Bool {
        assess(text, for: exercise) == .correct
    }

    static func assess(_ text: String, for exercise: GrammarExercise) -> Assessment {
        guard exercise.isUsable(for: exercise.ruleID) else { return .differsFromSample }
        if exercise.kind == .restoreSentence {
            let keys = exercise.options.filter { exercise.accepts($0.id) }.map(\.text) + (exercise.acceptedAnswers ?? [])
            return keys.contains { normalizeSentence($0, testsPunctuation: exercise.testsPunctuation == true)
                == normalizeSentence(text, testsPunctuation: exercise.testsPunctuation == true) }
                ? .correct : .differsFromSample
        }
        guard exercise.kind == .formProduction, exercise.validConjugation,
              let task = exercise.conjugation,
              let answer = GrammarConjugationEngine.conjugate(task.verb, to: task.form) else { return .differsFromSample }
        let normalized = normalizeForm(text)
        if ([answer.text, answer.reading] + (exercise.acceptedAnswers ?? [])).contains(where: { normalizeForm($0) == normalized }) {
            return .correct
        }
        // A rejected authored option has a diagnosis. An arbitrary free-text mismatch does not.
        if exercise.options.contains(where: {
            !exercise.accepts($0.id) && $0.feedbackRU?.isEmpty == false && normalizeForm($0.text) == normalized
        }) { return .incorrectForm }
        return .differsFromSample
    }

    private static func normalizeForm(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
    }

    static func normalizeSentence(_ text: String, testsPunctuation: Bool = false) -> String {
        var value = normalizeForm(text)
        if !testsPunctuation {
            // Remove one sentence terminator, not punctuation inside a sentence or ellipses.
            if let last = value.last, "。.!！?？".contains(last) {
                let prefix = String(value.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                if prefix.last.map({ !"。.!！?？…".contains($0) }) == true { value = prefix }
            }
        }
        let characters = Array(value)
        var result = ""
        var index = 0
        while index < characters.count {
            if characters[index].isWhitespace {
                let start = index
                while index < characters.count && characters[index].isWhitespace { index += 1 }
                // Space between Japanese elements is typographic. Preserve spaces in Latin words/numbers.
                if start > 0 && index < characters.count && japanese(characters[start - 1]) && japanese(characters[index]) {
                    continue
                }
                result.append(contentsOf: characters[start..<index])
            } else {
                result.append(characters[index]); index += 1
            }
        }
        return result
    }

    private static func japanese(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            switch $0.value {
            case 0x3001...0x3002, 0x3005...0x3007, 0x3040...0x30FF, 0x3400...0x4DBF,
                 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF: true
            default: false
            }
        }
    }
}
