import Foundation

enum WordUsageExampleProvider {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    static func loadExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        if !card.examples.isEmpty {
            return Array(card.examples.prefix(limit))
        }

        if let cachedExamples = loadCachedExamples(for: card.id) {
            return Array(cachedExamples.prefix(limit))
        }

        let remoteExamples = await loadRemoteExamples(for: card.word, limit: limit)
        saveCachedExamples(remoteExamples, for: card.id)
        return remoteExamples
    }

    private static func loadRemoteExamples(for word: String, limit: Int) async -> [WordUsageExample] {
        guard var components = URLComponents(string: "https://api.tatoeba.org/unstable/sentences") else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: word),
            URLQueryItem(name: "lang", value: "jpn"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "trans:lang", value: "eng")
        ]

        guard let url = components.url else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                return []
            }

            let payload = try JSONDecoder().decode(TatoebaSentenceResponse.self, from: data)
            return payload.data
                .filter { !$0.isUnapproved && $0.text.contains(word) }
                .prefix(limit)
                .map { sentence in
                    WordUsageExample(
                        sentence: sentence.text,
                        meaning: sentence.preferredEnglishTranslation
                    )
                }
        } catch {
            return []
        }
    }

    private static func loadCachedExamples(for wordID: String) -> [WordUsageExample]? {
        let store = loadCache()
        return store[wordID]
    }

    private static func saveCachedExamples(_ examples: [WordUsageExample], for wordID: String) {
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

private struct TatoebaSentenceResponse: Decodable {
    let data: [TatoebaSentence]
}

private struct TatoebaSentence: Decodable {
    let text: String
    let isUnapproved: Bool
    let translations: [TatoebaTranslation]

    enum CodingKeys: String, CodingKey {
        case text
        case isUnapproved = "is_unapproved"
        case translations
    }

    var preferredEnglishTranslation: String? {
        translations
            .first { $0.lang == "eng" && $0.isDirect }
            .map(\.text)
            ?? translations.first { $0.lang == "eng" }?.text
    }
}

private struct TatoebaTranslation: Decodable {
    let text: String
    let lang: String
    let isDirect: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case lang
        case isDirect = "is_direct"
    }
}
