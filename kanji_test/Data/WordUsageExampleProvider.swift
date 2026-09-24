import Foundation

protocol WordExampleProviding {
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample]
}

struct TatoebaWordExampleProvider: WordExampleProviding {
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
        if !card.examples.isEmpty {
            return Array(card.examples.prefix(limit))
        }

        if let cachedExamples = await WordExampleCacheRepository.loadExamples(for: card.id),
           !cachedExamples.isEmpty,
           cachedExamples.allSatisfy({ $0.attribution != nil && ($0.meaning == nil || $0.translationAttribution != nil) }) {
            return Array(cachedExamples.prefix(limit))
        }

        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        await WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id)
        return remoteExamples
    }

    func reloadRemoteExamples(for card: WordStudyCard, limit: Int = 3) async -> [WordUsageExample] {
        let remoteExamples = await loadRemoteExamples(for: card, limit: limit)
        if !remoteExamples.isEmpty {
            await WordExampleCacheRepository.saveExamples(remoteExamples, for: card.id)
        }
        return remoteExamples
    }

}
