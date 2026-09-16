import Foundation

enum WordExampleCacheRepository {
    static func loadExamples(for wordID: String) -> [WordUsageExample]? {
        loadCache()[wordID]
    }

    static func saveExamples(_ examples: [WordUsageExample], for wordID: String) {
        var store = loadCache()
        store[wordID] = examples

        do {
            let url = cacheURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to cache word usage examples: \(error)")
        }
    }

    private static func loadCache() -> [String: [WordUsageExample]] {
        let url = cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: [WordUsageExample]].self, from: data)
        } catch {
            return [:]
        }
    }

    private static func cacheURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("WordExampleCache", isDirectory: true)
            .appendingPathComponent("tatoeba-examples.json")
    }
}

enum KanjiExampleCacheRepository {
    static func loadExamples(for kanji: String) -> [KanjiExample]? {
        loadCache()[kanji]
    }

    static func saveExamples(_ examples: [KanjiExample], for kanji: String) {
        var store = loadCache()
        store[kanji] = examples

        do {
            let url = cacheURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to cache kanji examples: \(error)")
        }
    }

    private static func loadCache() -> [String: [KanjiExample]] {
        let url = cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: [KanjiExample]].self, from: data)
        } catch {
            return [:]
        }
    }

    private static func cacheURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("KanjiTatoebaExampleCache", isDirectory: true)
            .appendingPathComponent("tatoeba-kanji-examples.json")
    }
}
