import Foundation

extension KanjiDataLoader {
    static func loadCards(deck: KanjiDeck = .jlpt5, provider _: KanjiProviding = KanjiAPIProvider()) async -> [KanjiCard] {
        await loadAvailableCards(deck: deck)
    }

    static func loadCardsProgressively(
        deck: KanjiDeck,
        provider _: KanjiProviding = KanjiAPIProvider(),
        onUpdate: @MainActor @escaping ([KanjiCard], Int?) -> Void
    ) async {
        let cards = await loadAvailableCards(deck: deck)
        guard !Task.isCancelled else { return }
        onUpdate(cards, cards.count)
    }

    static func clearCache() async throws {
        try await KanjiDeckCacheRepository.shared.clearCache()
    }
}
