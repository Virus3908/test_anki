import Foundation

nonisolated enum GrammarExerciseKind: String, Codable, Sendable, CaseIterable {
    case chooseConstruction, fillBlank, identifyConstruction, chooseCorrectSentence, transformSentence
}

nonisolated struct GrammarExercise: Identifiable, Codable, Sendable {
    struct Option: Identifiable, Codable, Sendable {
        let id: String
        let text: String
        let feedbackRU: String?
    }
    let id: String
    let ruleID: String
    let kind: GrammarExerciseKind
    let promptRU: String
    let options: [Option]
    let acceptedOptionIDs: Set<String>
    let explanationRU: String
    let difficulty: Int
    let reviewer: String

    func accepts(_ optionID: String) -> Bool {
        options.contains { $0.id == optionID } && acceptedOptionIDs.contains(optionID)
    }
}

nonisolated struct GrammarExerciseResult: Sendable {
    let exerciseID: String
    let optionID: String
    let isCorrect: Bool
}

/// Presentation rotation only. It never submits FSRS ratings or changes stored content.
nonisolated enum GrammarExerciseSelection {
    static func ordered<T>(_ values: [T], seed: String) -> [T] {
        var result = values
        var state = seed.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            result.swapAt(index, Int(state % UInt64(index + 1)))
        }
        return result
    }
}
