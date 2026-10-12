import Foundation

extension KanjiDataLoader {
    static func loadExamplesIfNeeded(
        _ card: KanjiCard,
        provider: KanjiProviding = KanjiAPIProvider()
    ) async -> KanjiCard {
        let cached = await KanjiExampleCacheRepository.loadExamples(for: card.kanji)
        if !card.englishExamples.isEmpty {
            let candidates = card.englishExamples.map { example in
                cached?.first { $0.attribution?.sentenceID == example.attribution?.sentenceID
                    && example.attribution != nil && $0.word == example.word } ?? example
            }
            let examples = await provider.enrichExamples(candidates)
            await KanjiExampleCacheRepository.saveExamples(examples, for: card.kanji)
            return card.withEnglishExamples(examples)
        }

        if let cachedExamples = cached,
           !cachedExamples.isEmpty,
           cachedExamples.allSatisfy({
               $0.attribution != nil && ($0.meaning.isEmpty || $0.translationAttribution != nil)
           }) {
            let examples = await provider.enrichExamples(cachedExamples)
            await KanjiExampleCacheRepository.saveExamples(examples, for: card.kanji)
            return card.withEnglishExamples(examples)
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
