import Foundation

protocol KanjiProviding {
    func loadKanjiList(deck: KanjiDeck) async throws -> [String]
    func loadCards(deck: KanjiDeck) async throws -> [KanjiCard]
    func loadCards(for kanjiList: [String]) async throws -> [KanjiCard]
    func loadCardsStream(for kanjiList: [String]) -> AsyncStream<[KanjiCard]>
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

    func loadKanjiList(deck: KanjiDeck) async throws -> [String] {
        let (listData, response) = try await session.data(from: KanjiAPIEndpoint.kanjiList(deck: deck))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        return try JSONDecoder().decode([String].self, from: listData)
    }

    func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            guard let value = try await group.next() else {
                throw URLError(.timedOut)
            }

            group.cancelAll()
            return value
        }
    }
}
