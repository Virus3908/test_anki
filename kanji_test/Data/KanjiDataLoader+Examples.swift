import Foundation

extension KanjiDataLoader {
    static func loadExamplesIfNeeded(
        _ card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        guard card.englishExamples.isEmpty else {
            return card
        }

        if let cachedExamples = await KanjiExampleCacheRepository.loadExamples(for: card.kanji),
           !cachedExamples.isEmpty, cachedExamples.allSatisfy({ $0.attribution != nil }) {
            return card.withEnglishExamples(cachedExamples)
        }

        let remoteExamples = await provider.loadExamples(for: card.kanji)
        if !remoteExamples.isEmpty {
            await KanjiExampleCacheRepository.saveExamples(remoteExamples, for: card.kanji)
        }
        return card.withEnglishExamples(remoteExamples)
    }

    static func reloadExamples(
        for card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        let remoteExamples = await provider.loadExamples(for: card.kanji)
        if !remoteExamples.isEmpty {
            await KanjiExampleCacheRepository.saveExamples(remoteExamples, for: card.kanji)
        }
        return card.withEnglishExamples(remoteExamples)
    }

}
