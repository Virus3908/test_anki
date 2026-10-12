import Foundation

enum WordExampleCacheRepository {
    private static let store = ExampleCacheStore<WordUsageExample>(url:
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WordExampleCache/tatoeba-examples.json"))

    static func loadExamples(for wordID: String) async -> [WordUsageExample]? {
        await store.load(wordID)
    }

    static func saveExamples(_ examples: [WordUsageExample], for wordID: String) async {
        try? await store.save(examples, for: wordID)
    }
    static func clearCache() async throws { try await store.clear() }
}

enum KanjiExampleCacheRepository {
    private static let store = ExampleCacheStore<KanjiExample>(url:
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KanjiTatoebaExampleCache/tatoeba-kanji-examples.json"))

    static func loadExamples(for kanji: String) async -> [KanjiExample]? {
        await store.load(kanji)
    }

    static func saveExamples(_ examples: [KanjiExample], for kanji: String) async {
        try? await store.save(examples, for: kanji)
    }
    static func clearCache() async throws { try await store.clear() }
}
