import Foundation

enum WordExampleCacheRepository {
    private static let store = JSONFileStore(directory: .cachesDirectory, subdirectory: "WordExampleCache",
        filename: "tatoeba-examples.json", emptyValue: [String: [WordUsageExample]]())

    static func loadExamples(for wordID: String) async -> [WordUsageExample]? {
        (try? await store.load())?[wordID]
    }

    static func saveExamples(_ examples: [WordUsageExample], for wordID: String) async {
        try? await store.update { $0[wordID] = examples }
    }
}

enum KanjiExampleCacheRepository {
    private static let store = JSONFileStore(directory: .cachesDirectory, subdirectory: "KanjiTatoebaExampleCache",
        filename: "tatoeba-kanji-examples.json", emptyValue: [String: [KanjiExample]]())

    static func loadExamples(for kanji: String) async -> [KanjiExample]? {
        (try? await store.load())?[kanji]
    }

    static func saveExamples(_ examples: [KanjiExample], for kanji: String) async {
        try? await store.update { $0[kanji] = examples }
    }
}
