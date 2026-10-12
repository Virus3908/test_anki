import Foundation

protocol KanjiProviding {
    func loadExamples(for kanji: String) async -> [KanjiExample]
    func enrichExamples(_ examples: [KanjiExample]) async -> [KanjiExample]
}

struct KanjiAPIProvider: KanjiProviding {
    let session: URLSession

    nonisolated init(session: URLSession = KanjiAPIProvider.defaultSession) {
        self.session = session
    }

    nonisolated private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()
}

// Providers without Tatoeba metadata retain their existing behavior.
extension KanjiProviding {
    func enrichExamples(_ examples: [KanjiExample]) async -> [KanjiExample] { examples }
}

extension KanjiAPIProvider {
    func enrichExamples(_ examples: [KanjiExample]) async -> [KanjiExample] {
        await TatoebaWordExampleProvider(session: session).enrich(examples)
    }
}
