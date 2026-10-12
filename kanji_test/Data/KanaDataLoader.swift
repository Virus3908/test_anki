import Foundation

nonisolated enum KanaDataLoader {
    static func loadCards(deck: KanaDeck) async throws -> [KanaStudyCard] {
        try await BundledStudyData.shared.bundledKanaCards(deck: deck)
    }

    static func loadAllCards() async throws -> [KanaStudyCard] {
        var cards: [KanaStudyCard] = []
        for deck in KanaDeck.allCases {
            cards += try await loadCards(deck: deck)
        }
        return cards
    }

    static func clearCache() async throws {
        try await KanaSVGCacheRepository.shared.clearCache()
    }
}
