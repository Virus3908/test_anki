import Foundation

nonisolated struct StoredKanjiTranslation: Codable, Sendable {
    var russianMeanings: [String]?
    var russianExamples: [KanjiExample]?
}

nonisolated struct KanjiTranslationStore: Codable, Sendable {
    var kanjiTranslations: [String: StoredKanjiTranslation]
    var wordTranslations: [String: String]
    var wordExampleTranslations: [String: [WordUsageExample]]

    enum CodingKeys: String, CodingKey {
        case kanjiTranslations
        case wordTranslations
        case wordExampleTranslations
    }

    init(
        kanjiTranslations: [String: StoredKanjiTranslation] = [:],
        wordTranslations: [String: String] = [:],
        wordExampleTranslations: [String: [WordUsageExample]] = [:]
    ) {
        self.kanjiTranslations = kanjiTranslations
        self.wordTranslations = wordTranslations
        self.wordExampleTranslations = wordExampleTranslations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.kanjiTranslations) || container.contains(.wordTranslations)
                || container.contains(.wordExampleTranslations) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Неизвестный формат сохранённых переводов."))
        }
        kanjiTranslations = try container.decodeIfPresent([String: StoredKanjiTranslation].self, forKey: .kanjiTranslations) ?? [:]
        wordTranslations = try container.decodeIfPresent([String: String].self, forKey: .wordTranslations) ?? [:]
        wordExampleTranslations = try container.decodeIfPresent([String: [WordUsageExample]].self, forKey: .wordExampleTranslations) ?? [:]
    }
}
