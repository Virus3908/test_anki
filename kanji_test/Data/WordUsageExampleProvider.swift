import Foundation

protocol WordExampleProviding {
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
}

struct TatoebaWordExampleProvider: WordExampleProviding {
    private let session: URLSession

    nonisolated init(session: URLSession = TatoebaWordExampleProvider.defaultSession) {
        self.session = session
    }

    nonisolated private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    func loadExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        if !card.examples.isEmpty {
            return Array(card.examples.prefix(limit))
        }

        if let cachedExamples = WordExampleCacheRepository.loadExamples(for: card.id) {
            return Array(cachedExamples.prefix(limit))
        }

        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id)
        return remoteExamples
    }

    func reloadRemoteExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        if !remoteExamples.isEmpty {
            WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id)
        }
        return remoteExamples
    }

    private func loadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] {
        guard var components = URLComponents(string: "https://api.tatoeba.org/unstable/sentences") else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: card.word),
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
                .filter { !$0.isUnapproved && $0.text.contains(card.word) }
                .prefix(limit)
                .map { sentence in
                    WordUsageExample(
                        sentence: sentence.text,
                        reading: Self.fallbackReading(for: card, in: sentence.text),
                        meaning: sentence.preferredEnglishTranslation
                    )
                }
        } catch {
            return []
        }
    }

    private static func fallbackReading(for card: WordStudyCard, in sentence: String) -> String? {
        guard card.word != card.reading, sentence.contains(card.word) else {
            return nil
        }

        return "\(card.word): \(card.reading)"
    }

}

enum WordUsageExampleProvider {
    private static let provider = TatoebaWordExampleProvider()

    static func loadExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        await provider.loadExamples(for: card, limit: limit)
    }

    static func reloadRemoteExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        await provider.reloadRemoteExamples(for: card, limit: limit)
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
