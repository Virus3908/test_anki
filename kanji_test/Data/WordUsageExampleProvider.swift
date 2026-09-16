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
