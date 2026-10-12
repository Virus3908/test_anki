import Foundation

extension KanjiDataLoader {
    static func cachedExamples(for card: KanjiCard) async -> [KanjiExample] {
        let cached = await KanjiExampleCacheRepository.loadExamples(for: card.kanji)
        if !card.englishExamples.isEmpty {
            return card.englishExamples.map { example in
                cached?.first { $0.attribution?.sentenceID == example.attribution?.sentenceID
                    && example.attribution != nil && $0.word == example.word } ?? example
            }
        }
        guard let cached, !cached.isEmpty,
              cached.allSatisfy({ $0.attribution != nil && ($0.meaning.isEmpty || $0.translationAttribution != nil) }) else {
            return []
        }
        return cached
    }

    static func loadExamplesIfNeeded(
        _ card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        let cachedExamples = await cachedExamples(for: card)
        if !cachedExamples.isEmpty {
            let examples = await provider.enrichExamples(cachedExamples)
            if !Task.isCancelled { await KanjiExampleCacheRepository.saveExamples(examples, for: card.kanji) }
            return card.withEnglishExamples(examples)
        }

        let remoteExamples = await provider.loadExamples(for: card.kanji)
        if !Task.isCancelled, !remoteExamples.isEmpty {
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
