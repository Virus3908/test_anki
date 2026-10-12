import Foundation

protocol WordExampleProviding {
    func cachedExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
}

extension WordExampleProviding {
    func cachedExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] {
        Array(card.examples.prefix(limit))
    }
}

struct TatoebaWordExampleProvider: WordExampleProviding, Sendable {
    let session: URLSession

    nonisolated init(session: URLSession = TatoebaWordExampleProvider.defaultSession) {
        self.session = session
    }

    nonisolated private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    /// A cache-only snapshot for immediate presentation; never waits for the API.
    func cachedExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let cached = await WordExampleCacheRepository.loadExamples(for: card.id)
        if !card.examples.isEmpty {
            let candidates = card.examples.map { example in
                cached?.first { $0.attribution?.sentenceID == example.attribution?.sentenceID
                    && example.attribution != nil && $0.sentence == example.sentence } ?? example
            }
            return Array(candidates.prefix(limit))
        }

        if let cachedExamples = cached, !cachedExamples.isEmpty,
           cachedExamples.allSatisfy({ $0.attribution != nil && ($0.meaning == nil || $0.translationAttribution != nil) }) {
            return Array(cachedExamples.prefix(limit))
        }

        return []
    }

    func loadExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let cached = await cachedExamples(for: card, limit: card.examples.isEmpty ? .max : limit)
        if !cached.isEmpty {
            let examples = await enrich(Array(cached.prefix(limit)))
            var stored = cached
            for index in examples.indices { stored[index] = examples[index] }
            if !Task.isCancelled { await WordExampleCacheRepository.saveExamples(stored, for: card.id) }
            return examples
        }

        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        if !Task.isCancelled, !remoteExamples.isEmpty { await WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id) }
        return remoteExamples
    }

    func reloadRemoteExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        if !remoteExamples.isEmpty {
            if !Task.isCancelled, !remoteExamples.isEmpty { await WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id) }
        }
        return remoteExamples
    }

}
