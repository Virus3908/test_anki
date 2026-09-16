import Foundation

extension WordDataLoader {
    static func loadDictionaryEntries() async -> [WordDictionaryEntry] {
        loadBundledEntries()
    }

    static func loadBundledEntries() -> [WordDictionaryEntry] {
        guard let url = Bundle.main.url(forResource: "word-data", withExtension: "json") else {
            assertionFailure("word-data.json is missing from the app bundle.")
            return WordSeed.common
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WordDictionaryEntry].self, from: data)
        } catch {
            assertionFailure("Failed to decode word-data.json: \(error)")
            return WordSeed.common
        }
    }
}
