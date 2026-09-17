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

        if let cachedText = try await KanaSVGCacheRepository.shared.loadSVGText(fileName: fileName) {
            return cachedText
        }

        let url = URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(fileName)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let svgText = String(decoding: data, as: UTF8.self)
        try await KanaSVGCacheRepository.shared.saveSVGText(svgText, fileName: fileName)
        return svgText
    }

    private static func svgFileName(for character: String) -> String {
        guard let scalar = character.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }

    static func clearCache() async throws {
        try await KanaSVGCacheRepository.shared.clearCache()
    }
}
