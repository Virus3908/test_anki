import Foundation

enum KanaDataLoader {
    static func loadCards(deck: KanaDeck) async -> [KanaStudyCard] {
        let baseCards = deck.baseCards

        return await withTaskGroup(of: KanaStudyCard.self) { group in
            for card in baseCards {
                group.addTask {
                    await loadCard(card)
                }
            }

            var cardsByCharacter: [String: KanaStudyCard] = [:]
            for await card in group {
                cardsByCharacter[card.character] = card
            }

            return baseCards.map { cardsByCharacter[$0.character] ?? $0 }
        }
    }

    private static func loadCard(_ card: KanaStudyCard) async -> KanaStudyCard {
        guard card.character.unicodeScalars.count == 1 else {
            return card
        }

        do {
            let svgText = try await loadSVGText(for: card.character)
            let strokes = SVGStrokeExtractor.strokes(from: svgText)
            guard !strokes.isEmpty else {
                return card
            }

            return KanaStudyCard(character: card.character, reading: card.reading, strokes: strokes)
        } catch {
            return card
        }
    }

    private static func loadSVGText(for character: String) async throws -> String {
        let fileName = svgFileName(for: character)
        let cachedURL = cacheURL(for: fileName)

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return try String(contentsOf: cachedURL, encoding: .utf8)
        }

        let url = URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(fileName)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let svgText = String(decoding: data, as: UTF8.self)
        try FileManager.default.createDirectory(at: cachedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgText.write(to: cachedURL, atomically: true, encoding: .utf8)
        return svgText
    }

    private static func svgFileName(for character: String) -> String {
        guard let scalar = character.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }

    static func clearCache() {
        let directory = cacheDirectoryURL()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try? FileManager.default.removeItem(at: directory)
    }

    private static func cacheURL(for fileName: String) -> URL {
        cacheDirectoryURL().appendingPathComponent(fileName)
    }

    private static func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanaVGCache", isDirectory: true)
    }
}
