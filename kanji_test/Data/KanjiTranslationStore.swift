import Foundation

struct StoredKanjiTranslation: Codable {
    var russianMeanings: [String]?
    var russianExamples: [KanjiExample]?
}

struct KanjiTranslationStore: Codable {
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
        kanjiTranslations = try container.decodeIfPresent([String: StoredKanjiTranslation].self, forKey: .kanjiTranslations) ?? [:]
        wordTranslations = try container.decodeIfPresent([String: String].self, forKey: .wordTranslations) ?? [:]
        wordExampleTranslations = try container.decodeIfPresent([String: [WordUsageExample]].self, forKey: .wordExampleTranslations) ?? [:]
    }

    func applying(to card: KanjiCard) -> KanjiCard {
        guard let translation = kanjiTranslations[card.kanji] else {
            return card
        }

        var translatedCard = card
        if let russianMeanings = translation.russianMeanings, !russianMeanings.isEmpty {
            translatedCard = translatedCard.withRussianMeanings(russianMeanings)
        }

        if let russianExamples = translation.russianExamples, !russianExamples.isEmpty {
            translatedCard = translatedCard.withRussianExamples(russianExamples)
        }

        return translatedCard
    }

    mutating func mergeKanjiTranslation(from card: KanjiCard) {
        var translation = kanjiTranslations[card.kanji] ?? StoredKanjiTranslation()
        if card.hasRussianMeanings {
            translation.russianMeanings = card.cachedRussianMeanings
        }

        if card.hasRussianExamples {
            translation.russianExamples = card.cachedRussianExamples
        }

        kanjiTranslations[card.kanji] = translation
    }
}
