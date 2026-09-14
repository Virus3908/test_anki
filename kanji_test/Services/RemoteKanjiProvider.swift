import Foundation

enum RemoteKanjiProvider {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()

    static func loadKanjiList(deck: KanjiDeck) async throws -> [String] {
        let listURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(deck.endpointPath)")!
        let (listData, _) = try await session.data(from: listURL)
        return try JSONDecoder().decode([String].self, from: listData)
    }

    static func loadCards(deck: KanjiDeck) async throws -> [KanjiCard] {
        let kanjiList = try await loadKanjiList(deck: deck)
        return try await loadCards(for: kanjiList)
    }

    static func loadCards(for kanjiList: [String]) async throws -> [KanjiCard] {
        var cards: [KanjiCard] = []
        var nextIndex = 0
        let maxConcurrentRequests = 16

        await withTaskGroup(of: KanjiCard?.self) { group in
            func enqueueNextCard() {
                guard nextIndex < kanjiList.count else {
                    return
                }

                let kanji = kanjiList[nextIndex]
                nextIndex += 1
                group.addTask {
                    try? await loadCard(for: kanji)
                }
            }

            for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                enqueueNextCard()
            }

            for await card in group {
                if let card {
                    cards.append(card)
                }

                enqueueNextCard()
            }
        }

        return cards.sorted { $0.kanji < $1.kanji }
    }

    static func loadCardsStream(for kanjiList: [String]) -> AsyncStream<[KanjiCard]> {
        AsyncStream { continuation in
            let task = Task {
                var batch: [KanjiCard] = []
                var didYieldFirstCard = false
                var nextIndex = 0
                let maxConcurrentRequests = 8

                await withTaskGroup(of: KanjiCard?.self) { group in
                    func enqueueNextCard() {
                        guard nextIndex < kanjiList.count else {
                            return
                        }

                        let kanji = kanjiList[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            try? await loadCard(for: kanji)
                        }
                    }

                    for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                        enqueueNextCard()
                    }

                    for await card in group {
                        guard !Task.isCancelled else {
                            return
                        }

                        if let card {
                            if didYieldFirstCard {
                                batch.append(card)
                            } else {
                                continuation.yield([card])
                                didYieldFirstCard = true
                            }
                        }

                        if batch.count >= 8 {
                            continuation.yield(batch)
                            batch.removeAll(keepingCapacity: true)
                        }

                        enqueueNextCard()
                    }
                }

                if !batch.isEmpty {
                    continuation.yield(batch)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func loadCard(for kanji: String) async throws -> KanjiCard {
        let detailURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(kanji)")!
        let svgURL = URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(svgFileName(for: kanji))")!

        async let detailData = session.data(from: detailURL).0
        async let svgData = session.data(from: svgURL).0

        let detail = try JSONDecoder().decode(RemoteKanjiDetail.self, from: try await detailData)
        let svgText = String(decoding: try await svgData, as: UTF8.self)
        let strokes = SVGStrokeExtractor.strokes(from: svgText)

        guard !strokes.isEmpty else {
            throw RemoteKanjiError.missingStrokes
        }

        let loadedExamples = await loadExamples(for: kanji)

        return KanjiCard(
            kanji: detail.kanji,
            meanings: detail.meanings,
            onyomi: detail.onReadings,
            kunyomi: detail.kunReadings,
            examples: loadedExamples,
            source: KanjiSource(
                name: "kanjiapi.dev + KanjiVG",
                file: svgFileName(for: kanji),
                license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"
            ),
            strokes: strokes,
            grade: detail.grade,
            jlpt: detail.jlpt
        )
    }

    private static func loadExamples(for kanji: String) async -> [KanjiExample] {
        do {
            let wordsURL = URL(string: "https://kanjiapi.dev/v1/words/\(kanji)")!
            let (data, _) = try await withTimeout(seconds: 3) {
                try await session.data(from: wordsURL)
            }
            let entries = try JSONDecoder().decode([RemoteWordEntry].self, from: data)
            var examples: [KanjiExample] = []

            for entry in entries.prefix(30) {
                let englishMeaning = entry.meanings.flatMap(\.glosses).prefix(2).joined(separator: ", ")

                for variant in entry.variants where variant.written.contains(kanji) {
                    examples.append(KanjiExample(word: variant.written, reading: variant.pronounced, meaning: englishMeaning))

                    if examples.count == 6 {
                        return examples
                    }
                }
            }

            return examples
        } catch {
            return []
        }
    }

    private static func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
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

    private static func svgFileName(for kanji: String) -> String {
        guard let scalar = kanji.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }
}

private struct RemoteKanjiDetail: Decodable {
    let kanji: String
    let meanings: [String]
    let onReadings: [String]
    let kunReadings: [String]
    let grade: Int?
    let jlpt: Int?

    enum CodingKeys: String, CodingKey {
        case kanji
        case meanings
        case onReadings = "on_readings"
        case kunReadings = "kun_readings"
        case grade
        case jlpt
    }
}

private struct RemoteWordEntry: Decodable {
    let meanings: [RemoteWordMeaning]
    let variants: [RemoteWordVariant]
}

private struct RemoteWordMeaning: Decodable {
    let glosses: [String]
}

private struct RemoteWordVariant: Decodable {
    let pronounced: String
    let written: String
}

private enum RemoteKanjiError: Error {
    case missingStrokes
}
