import Foundation

/// Bundle reads/decoding and validation run on this actor, never in SwiftUI body.
actor GrammarDataLoader {
    static let shared = GrammarDataLoader()
    private let resourceURLs: [GrammarLevel: URL]
    private var cached: [GrammarLevel: GrammarResource] = [:]

    init(resourceURLs: [GrammarLevel: URL]? = nil) {
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
        let value = try JSONDecoder().decode(GrammarResource.self, from: Data(contentsOf: url))
        try Self.validate(value, level: level)
        try Task.checkCancellation()
        cached[level] = value
        return value
    }

    func rules(_ level: GrammarLevel) throws -> [GrammarRule] { try resource(level).rules }

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
            try require(rule.tags.allSatisfy { GrammarCategory(rawValue: $0) != nil }, "неизвестная категория \(rule.id)")
            if let ru = rule.localization {
                try require([ru.meaningRU, ru.formationRU, ru.formationNotesRU, ru.explanationRU, ru.reviewer].allSatisfy(nonempty)
                    && rule.examples.allSatisfy { $0.ru.map(nonempty) == true }, "неполная русская локализация \(rule.id)")
            }
            for exercise in rule.exercises ?? [] {
                try require(nonempty(exercise.id) && exerciseIDs.insert(exercise.id).inserted
                    && exercise.ruleID == rule.id && nonempty(exercise.promptRU)
                    && nonempty(exercise.explanationRU) && nonempty(exercise.reviewer), "неполное задание \(rule.id)")
                let optionIDs = Set(exercise.options.map(\.id))
                try require(exercise.options.count >= 2 && optionIDs.count == exercise.options.count
                    && exercise.options.allSatisfy { nonempty($0.id) && nonempty($0.text) }
                    && Set(exercise.options.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }).count == exercise.options.count
                    && !exercise.acceptedOptionIDs.isEmpty && exercise.acceptedOptionIDs.isSubset(of: optionIDs)
                    && exercise.acceptedOptionIDs.count < exercise.options.count, "неверный ключ ответа \(exercise.id)")
            }
        }
    }
}
