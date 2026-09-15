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

    static func load() -> KanjiTranslationStore {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return KanjiTranslationStore(kanjiTranslations: [:], wordTranslations: [:])
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KanjiTranslationStore.self, from: data)
        } catch {
            assertionFailure("Failed to load translation store: \(error)")
            return KanjiTranslationStore(kanjiTranslations: [:], wordTranslations: [:])
        }
    }

    static func apply(to cards: [KanjiCard]) -> [KanjiCard] {
        let store = load()
        return cards.map { store.applying(to: $0) }
    }

    static func migrateKanjiTranslations(from cards: [KanjiCard]) {
        guard cards.contains(where: { $0.hasRussianMeanings || $0.hasRussianExamples }) else {
            return
        }

        var store = load()
        for card in cards {
            store.mergeKanjiTranslation(from: card)
        }
        store.save()
    }

    static func saveKanjiTranslation(from card: KanjiCard) {
        var store = load()
        store.mergeKanjiTranslation(from: card)
        store.save()
    }

    static func loadWordTranslations() -> [String: String] {
        load().wordTranslations
    }

    static func loadWordExampleTranslations() -> [String: [WordUsageExample]] {
        load().wordExampleTranslations
    }

    static func saveWordTranslation(_ translation: String, for wordID: String) {
        var store = load()
        store.wordTranslations[wordID] = translation
        store.save()
    }

    static func saveWordExampleTranslation(_ examples: [WordUsageExample], for wordID: String) {
        var store = load()
        store.wordExampleTranslations[wordID] = examples
        store.save()
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

    private func save() {
        do {
            let url = try Self.storageURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save translation store: \(error)")
        }
    }

    private static func storageURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return directory
            .appendingPathComponent("KanjiTrainer", isDirectory: true)
            .appendingPathComponent("translations.json")
    }
}
