import Foundation

enum TranslationRepository {
    static func loadStore() -> KanjiTranslationStore {
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

    static func saveStore(_ store: KanjiTranslationStore) {
        do {
            let url = try storageURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save translation store: \(error)")
        }
    }

    static func apply(to cards: [KanjiCard]) -> [KanjiCard] {
        let store = loadStore()
        return cards.map { store.applying(to: $0) }
    }

    static func migrateKanjiTranslations(from cards: [KanjiCard]) {
        guard cards.contains(where: { $0.hasRussianMeanings || $0.hasRussianExamples }) else {
            return
        }

        var store = loadStore()
        for card in cards {
            store.mergeKanjiTranslation(from: card)
        }
        saveStore(store)
    }

    static func saveKanjiTranslation(from card: KanjiCard) {
        var store = loadStore()
        store.mergeKanjiTranslation(from: card)
        saveStore(store)
    }

    static func loadWordTranslations() -> [String: String] {
        loadStore().wordTranslations
    }

    static func loadKanjiMeaningTranslations() -> [String: [String]] {
        loadStore().kanjiTranslations.compactMapValues { translation in
            guard let meanings = translation.russianMeanings, !meanings.isEmpty else {
                return nil
            }

            return meanings
        }
    }

    static func loadWordExampleTranslations() -> [String: [WordUsageExample]] {
        loadStore().wordExampleTranslations
    }

    static func saveWordTranslation(_ translation: String, for wordID: String) {
        var store = loadStore()
        store.wordTranslations[wordID] = translation
        saveStore(store)
    }

    static func saveKanjiMeaningTranslation(_ meanings: [String], for kanji: String) {
        var store = loadStore()
        var translation = store.kanjiTranslations[kanji] ?? StoredKanjiTranslation()
        translation.russianMeanings = meanings
        store.kanjiTranslations[kanji] = translation
        saveStore(store)
    }

    static func saveWordExampleTranslation(_ examples: [WordUsageExample], for wordID: String) {
        var store = loadStore()
        store.wordExampleTranslations[wordID] = examples
        saveStore(store)
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
