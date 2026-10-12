import Foundation

nonisolated enum GrammarExerciseKind: String, Codable, Sendable, CaseIterable {
    case chooseConstruction, fillBlank, identifyConstruction, chooseCorrectSentence, transformSentence
    var title: String {
        switch self {
        case .chooseConstruction: "Выбор конструкции"
        case .fillBlank: "Заполнение пропуска"
        case .identifyConstruction: "Определение конструкции"
        case .chooseCorrectSentence: "Правильное употребление"
        case .transformSentence: "Преобразование предложения"
        }
    }
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
    let reviewer: String?
    let cueEN: String?
    let explanationEN: String?
    let provenance: Provenance?

    struct Provenance: Codable, Sendable {
        enum Status: String, Codable, Sendable { case draft, automaticallyChecked, linguisticallyReviewed }
        let commit: String
        let sourceRuleID: String
        let exampleIndex: Int?
        let method: String
        let status: Status
    }

    init(id: String, ruleID: String, kind: GrammarExerciseKind, promptRU: String,
         options: [Option], acceptedOptionIDs: Set<String>, explanationRU: String,
         difficulty: Int, reviewer: String? = nil, cueEN: String? = nil, explanationEN: String? = nil,
         provenance: Provenance? = nil) {
        self.id = id; self.ruleID = ruleID; self.kind = kind; self.promptRU = promptRU
        self.options = options; self.acceptedOptionIDs = acceptedOptionIDs
        self.explanationRU = explanationRU; self.difficulty = difficulty; self.reviewer = reviewer
        self.cueEN = cueEN; self.explanationEN = explanationEN; self.provenance = provenance
    }

    func accepts(_ optionID: String) -> Bool {
        options.contains { $0.id == optionID } && acceptedOptionIDs.contains(optionID)
    }

    func isUsable(for ruleID: String) -> Bool {
        let ids = Set(options.map(\.id))
        return self.ruleID == ruleID && !id.isEmpty && !promptRU.isEmpty && !explanationRU.isEmpty
            && options.count == 4 && ids.count == 4
            && options.allSatisfy { !$0.id.isEmpty && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && Set(options.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }).count == 4
            && !acceptedOptionIDs.isEmpty && acceptedOptionIDs.isSubset(of: ids) && acceptedOptionIDs.count < 4
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
