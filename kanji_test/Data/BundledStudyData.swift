import Foundation

actor BundledStudyData {
    static let shared = BundledStudyData()
    private var words: [WordDictionaryEntry]?
    private var kanji: [String: [KanjiCard]] = [:]

    func wordEntries() throws -> [WordDictionaryEntry] {
        if let words { return words }
        let loaded: [WordDictionaryEntry] = try decode("word-data")
        words = loaded
        return loaded
    }

    func kanjiCards(resource: String) throws -> [KanjiCard] {
        if let cached = kanji[resource] { return cached }
        let loaded: [KanjiCard] = try decode(resource)
        kanji[resource] = loaded
        return loaded
    }

    private func decode<Value: Decodable>(_ resource: String) throws -> Value {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
}
