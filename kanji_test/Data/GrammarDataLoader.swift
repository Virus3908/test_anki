import Foundation

/// Bundle reads/decoding and validation run on this actor, never in SwiftUI body.
actor GrammarDataLoader {
    static let shared = GrammarDataLoader()
    private let resourceURLs: [GrammarLevel: URL]
    private var cached: [GrammarLevel: GrammarResource] = [:]
    private var sentenceBank: GrammarSentenceBank?
    private let sentenceBankURL: URL?

    init(resourceURLs: [GrammarLevel: URL]? = nil, sentenceBankURL: URL? = nil) {
        self.sentenceBankURL = sentenceBankURL ?? Bundle.main.url(forResource: "grammar-sentence-bank", withExtension: "json")
            ?? Bundle.main.url(forResource: "grammar-sentence-bank", withExtension: "json", subdirectory: "Data/Grammar")
        self.resourceURLs = resourceURLs ?? Dictionary(uniqueKeysWithValues: GrammarLevel.allCases.compactMap { level in
            let name = "grammar-\(level.rawValue.lowercased())"
            guard let url = Bundle.main.url(forResource: name, withExtension: "json")
                ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Data/Grammar") else { return nil }
            return (level, url)
        })
    }

    enum Error: LocalizedError {
        case missing(GrammarLevel), invalid(String)
        var errorDescription: String? {
            switch self {
            case .missing(let level): "Не найден встроенный ресурс грамматики \(level.rawValue)."
            case .invalid(let message): "Повреждены данные грамматики: \(message)"
            }
        }
    }

    func resource(_ level: GrammarLevel) throws -> GrammarResource {
        try Task.checkCancellation()
        if let value = cached[level] { return value }
        guard let url = resourceURLs[level] else { throw Error.missing(level) }
        let decoded = try JSONDecoder().decode(GrammarResource.self, from: Data(contentsOf: url))
        var value = decoded
        if decoded.rules.contains(where: { $0.exampleReferences != nil || $0.exerciseTemplateIDs != nil }) {
            let bank = try loadSentenceBank()
            let rules = try decoded.rules.map { rule in
                let examples = try rule.exampleReferences.map(bank.examples) ?? rule.examples
                // Bad referenced exercises disable just their rule, as legacy malformed arrays do.
                let exercises = rule.exerciseTemplateIDs.map { try? bank.exercises($0, ruleID: rule.id) } ?? rule.exercises
                let studyExamples = try rule.studyExampleReferences.map(bank.examples) ?? rule.studyExamples
                for reference in rule.studyExampleReferences ?? [] {
                    guard let usageID = reference.usageID,
                          bank.usages.contains(where: { $0.id == usageID && $0.ruleID == rule.id
                              && $0.sentenceID == reference.sentenceID && !$0.eligibleForScoring }) else {
                        throw Error.invalid("неверная привязка учебного контекста \(rule.id)")
                    }
                }
                return rule.withCorpus(examples: examples, exercises: exercises, studyExamples: studyExamples)
            }
            value = GrammarResource(schemaVersion: decoded.schemaVersion, metadata: decoded.metadata, rules: rules)
        }
        try Self.validate(value, level: level)
        try Task.checkCancellation()
        cached[level] = value
        return value
    }

    func rules(_ level: GrammarLevel) throws -> [GrammarRule] { try resource(level).rules }
    func loadSentenceBank() throws -> GrammarSentenceBank {
        if let sentenceBank { return sentenceBank }
        guard let sentenceBankURL else { throw Error.invalid("не найден банк предложений") }
        let bank = try JSONDecoder().decode(GrammarSentenceBank.self, from: Data(contentsOf: sentenceBankURL))
        try bank.validate()
        sentenceBank = bank
        return bank
    }

    func allRules() throws -> [GrammarRule] {
        let values = try GrammarLevel.allCases.flatMap { try rules($0) }
        let ids = Set(values.map(\.id))
        guard ids.count == values.count else { throw Error.invalid("повторяющиеся ID между уровнями") }
        for rule in values {
            guard (rule.relations ?? []).allSatisfy({ ids.contains($0.ruleID) && $0.ruleID != rule.id }) else {
                throw Error.invalid("ссылка на неизвестное правило \(rule.id)")
            }
        }
        return values
    }

    func rule(_ id: String) throws -> GrammarRule? { try allRules().first { $0.id == id } }
    func rules(category: GrammarCategory) throws -> [GrammarRule] { try allRules().filter { $0.categories.contains(category) } }
    func related(to rule: GrammarRule) throws -> [GrammarRule] {
        let all = try allRules()
        return (rule.relations ?? []).compactMap { relation in all.first { $0.id == relation.ruleID } }
    }

    nonisolated static func validate(_ resource: GrammarResource, level: GrammarLevel) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Error.invalid(message) }
        }
        func nonempty(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        try require(resource.schemaVersion == 1, "неподдерживаемая версия ресурса")
        try require(resource.metadata.commit == "0d1d3410bec90bd4098a7c72de820543cb4f707c"
            && resource.metadata.license == "CC-BY-SA-4.0"
            && !resource.metadata.authors.isEmpty, "нет атрибуции закреплённого источника")
        try require(resource.rules.count == level.expectedCount, "неполный уровень \(level.rawValue)")
        try require(Set(resource.rules.map(\.id)).count == resource.rules.count, "повторяющийся ID")
        var exerciseIDs = Set<String>()
        for rule in resource.rules {
            try Task.checkCancellation()
            try require(rule.level == level && nonempty(rule.id) && nonempty(rule.pattern)
                && nonempty(rule.meaning) && nonempty(rule.formation), "пустые обязательные поля \(rule.id)")
            try require(!rule.examples.isEmpty && rule.examples.allSatisfy { nonempty($0.ja) && nonempty($0.en) },
                "нет примеров/переводов \(rule.id)")
            try require(rule.studyExamples.allSatisfy { example in nonempty(example.ja) && example.ru.map(nonempty) == true
                && example.preparationStatus == "assistantPrepared" && example.ruby != nil
                && example.targetConstruction.map { nonempty($0) && example.ja.contains($0) } == true && example.skillRU.map(nonempty) == true },
                "неполный подготовленный контекст \(rule.id)")
            try require(rule.tags.allSatisfy { GrammarCategory(rawValue: $0) != nil }, "неизвестная категория \(rule.id)")
            if let ru = rule.localization {
                try require([ru.meaningRU, ru.formationRU, ru.formationNotesRU, ru.explanationRU, ru.reviewer].allSatisfy(nonempty)
                    && rule.examples.allSatisfy { $0.ru.map(nonempty) == true }, "неполная русская локализация \(rule.id)")
            }
            for exercise in rule.exercises ?? [] {
                try require(nonempty(exercise.id) && exerciseIDs.insert(exercise.id).inserted
                    && exercise.ruleID == rule.id && nonempty(exercise.promptRU)
                    && nonempty(exercise.explanationRU), "неполное задание \(rule.id)")
                try require(exercise.isUsable(for: rule.id), "неверный ключ ответа \(exercise.id)")
            }
        }
    }
}
