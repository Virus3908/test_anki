import Foundation

nonisolated enum GrammarExerciseKind: String, Codable, Sendable, CaseIterable {
    case formProduction, chooseConstruction, fillBlank, identifyConstruction, chooseCorrectSentence, transformSentence
    case assembleSentence, chooseContext, correctError, distinguishMeaning, understandSentence
    var title: String {
        switch self {
        case .formProduction: "Образование формы"
        case .chooseConstruction: "Выбор конструкции"
        case .fillBlank: "Заполнение пропуска"
        case .identifyConstruction: "Определение конструкции"
        case .chooseCorrectSentence: "Правильное употребление"
        case .transformSentence: "Преобразование предложения"
        case .assembleSentence: "Собери предложение"
        case .chooseContext: "Применение в ситуации"
        case .correctError: "Исправление ошибки"
        case .distinguishMeaning: "Различение значений"
        case .understandSentence: "Понимание предложения"
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
    var japanese: String? = nil
    var aspect: String? = nil
    var hintRU: String? = nil
    var acceptedOrders: [[String]]? = nil
    /// Explicit editorial eligibility, independent of provenance/reviewer status.
    var isScored: Bool? = nil
    var conjugation: ConjugationTask? = nil
    var competency: GrammarCompetency? = nil

    struct ConjugationTask: Codable, Sendable {
        let verb: GrammarConjugationEngine.Verb
        let form: GrammarConjugationEngine.Form
    }

    struct Provenance: Codable, Sendable {
        enum Status: String, Codable, Sendable { case draft, automaticallyChecked, structurallyChecked, algorithmicallyChecked, linguisticallyReviewed }
        let commit: String
        let sourceRuleID: String
        let exampleIndex: Int?
        let method: String
        let status: Status
    }

    init(id: String, ruleID: String, kind: GrammarExerciseKind, promptRU: String,
         options: [Option], acceptedOptionIDs: Set<String>, explanationRU: String,
         difficulty: Int, reviewer: String? = nil, cueEN: String? = nil, explanationEN: String? = nil,
         provenance: Provenance? = nil, japanese: String? = nil, aspect: String? = nil,
         hintRU: String? = nil, acceptedOrders: [[String]]? = nil, isScored: Bool? = nil) {
        self.id = id; self.ruleID = ruleID; self.kind = kind; self.promptRU = promptRU
        self.options = options; self.acceptedOptionIDs = acceptedOptionIDs
        self.explanationRU = explanationRU; self.difficulty = difficulty; self.reviewer = reviewer
        self.cueEN = cueEN; self.explanationEN = explanationEN; self.provenance = provenance
        self.japanese = japanese; self.aspect = aspect; self.hintRU = hintRU
        self.acceptedOrders = acceptedOrders; self.isScored = isScored
    }

    func accepts(_ optionID: String) -> Bool {
        options.contains { $0.id == optionID } && acceptedOptionIDs.contains(optionID)
    }

    func isUsable(for ruleID: String) -> Bool {
        let ids = Set(options.map(\.id))
        let validAnswers: Bool
        if kind == .assembleSentence {
            validAnswers = !(acceptedOrders ?? []).isEmpty && (acceptedOrders ?? []).allSatisfy {
                !$0.isEmpty && Set($0).count == $0.count && Set($0).isSubset(of: ids)
            }
        } else {
            validAnswers = !acceptedOptionIDs.isEmpty && acceptedOptionIDs.isSubset(of: ids)
                && acceptedOptionIDs.count < options.count
        }
        return self.ruleID == ruleID && !id.isEmpty && !promptRU.isEmpty && !explanationRU.isEmpty
            && options.count >= 2 && ids.count == options.count
            && options.allSatisfy { !$0.id.isEmpty && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && Set(options.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }).count == options.count
            && (1...3).contains(difficulty) && validAnswers && validConjugation
    }

    var validConjugation: Bool {
        guard let conjugation else { return kind != .formProduction }
        guard let answer = GrammarConjugationEngine.conjugate(conjugation.verb, to: conjugation.form) else { return false }
        let accepted = options.filter { acceptedOptionIDs.contains($0.id) }.map(\.text)
        return !accepted.isEmpty && accepted.allSatisfy { $0 == answer.text || $0 == answer.reading }
    }

    var eligibleForPractice: Bool {
        isScored == true && kind != .chooseConstruction && kind != .identifyConstruction
            && ([Provenance.Status.automaticallyChecked, .structurallyChecked, .algorithmicallyChecked, .linguisticallyReviewed].contains { $0 == provenance?.status })
    }
    func accepts(order: [String]) -> Bool { acceptedOrders?.contains(order) == true }
    var correctAnswer: String {
        if kind == .assembleSentence, let order = acceptedOrders?.first {
            return order.compactMap { id in options.first { $0.id == id }?.text }.joined()
        }
        return options.filter { accepts($0.id) }.map(\.text).joined(separator: " / ")
    }
}

nonisolated struct GrammarExerciseResult: Sendable {
    let exerciseID: String
    let optionID: String
    let isCorrect: Bool
    var usedHint: Bool = false
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
