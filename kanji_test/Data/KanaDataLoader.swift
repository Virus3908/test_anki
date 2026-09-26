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
            let strokes = try BundledKanjiVG.strokes(for: card.character)

            return KanaStudyCard(character: card.character, reading: card.reading, strokes: strokes)
        } catch {
            return card
        }
    }

    static func clearCache() async throws {
        try await KanaSVGCacheRepository.shared.clearCache()
    }
}
