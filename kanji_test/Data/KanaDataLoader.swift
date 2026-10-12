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
        // Migration cleanup only: bundled kana metadata/geometry are immutable.
        let legacy = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KanaVGCache", isDirectory: true)
        let worker = Task.detached(priority: .utility) {
            if FileManager.default.fileExists(atPath: legacy.path) {
                try FileManager.default.removeItem(at: legacy)
            }
        }
        try await worker.value
    }
}
