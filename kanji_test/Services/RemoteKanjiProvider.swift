import Foundation

protocol KanjiProviding {
    func loadExamples(for kanji: String) async -> [KanjiExample]
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
