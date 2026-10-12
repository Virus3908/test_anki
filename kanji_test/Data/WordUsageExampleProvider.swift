import Foundation

protocol WordExampleProviding {
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
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

    func loadExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let cached = await WordExampleCacheRepository.loadExamples(for: card.id)
        if !card.examples.isEmpty {
            let candidates = card.examples.map { example in
                cached?.first { $0.attribution?.sentenceID == example.attribution?.sentenceID
                    && example.attribution != nil && $0.sentence == example.sentence } ?? example
            }
            let examples = await enrich(Array(candidates.prefix(limit)))
            if !Task.isCancelled { await WordExampleCacheRepository.saveExamples(examples, for: card.id) }
            return examples
        }

        if let cachedExamples = cached, !cachedExamples.isEmpty,
           cachedExamples.allSatisfy({ $0.attribution != nil && ($0.meaning == nil || $0.translationAttribution != nil) }) {
            let examples = await enrich(cachedExamples)
            if !Task.isCancelled { await WordExampleCacheRepository.saveExamples(examples, for: card.id) }
            return Array(examples.prefix(limit))
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
