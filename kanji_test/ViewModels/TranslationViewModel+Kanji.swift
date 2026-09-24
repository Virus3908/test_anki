import Foundation

extension TranslationViewModel {
    func displayedKanjiMeanings(for card: KanjiCard, language: MeaningLanguage) -> [String] {
        language == .russian ? cached(.kanjiMeaning(card.id), source: card.englishMeanings) ?? card.englishMeanings : card.englishMeanings
    }
    func originalKanjiExamples(for card: KanjiCard) -> [KanjiExample] { kanjiUsageExamples[card.id] ?? card.englishExamples }
    func kanjiExampleSource(_ examples: [KanjiExample]) -> [String] { examples.flatMap { [$0.word, $0.reading, $0.meaning] } }
    func displayedKanjiExamples(for card: KanjiCard, language: MeaningLanguage) -> [KanjiExample] {
        let examples = originalKanjiExamples(for: card)
        guard language == .russian, let meanings = cached(.kanjiExamples(card.id), source: kanjiExampleSource(examples)),
              meanings.count == examples.count else { return examples }
        return zip(examples, meanings).map {
            KanjiExample(word: $0.word, reading: $0.reading, meaning: $1, attribution: $0.attribution,
                         translationAttribution: $0.translationAttribution)
        }
    }
    func translateKanjiMeaningsIfNeeded(for card: KanjiCard, deck: KanjiDeck, language: MeaningLanguage) async {
        guard language == .russian else { return }
        await translateAutomatically(.kanjiMeaning(card.id), texts: card.englishMeanings, source: card.englishMeanings,
                                     legacy: store.legacy.kanjiTranslations[card.id]?.russianMeanings)
    }
    func retranslateKanjiMeanings(_ card: KanjiCard, deck: KanjiDeck, language: MeaningLanguage) {
        guard language == .russian else { return }
        let key = TranslationBlockKey.kanjiMeaning(card.id)
        runManual(key, kind: .manualTranslation) { id in
            await self.translate(key, texts: card.englishMeanings, source: card.englishMeanings, manual: true, id: id)
        }
    }
    func loadKanjiExamplesIfNeeded(for card: KanjiCard, language: MeaningLanguage) async {
        let key = TranslationBlockKey.kanjiExamples(card.id)
        guard let id = beginAutomatic(key, kind: .automaticTranslation) else { return }
        defer { end(id, key: key) }
        let examples: [KanjiExample]
        if let loaded = kanjiUsageExamples[card.id] { examples = loaded }
        else {
            examples = await KanjiDataLoader.loadExamplesIfNeeded(card, provider: kanjiProvider).englishExamples
        }
        guard current(id, key: key) else { return }
        kanjiUsageExamples[card.id] = examples
        guard language == .russian else { return }
        let old = store.legacy.kanjiTranslations[card.id]?.russianExamples
        let legacy = old?.map(\.id) == examples.map(\.id) ? old?.map(\.meaning) : nil
        await translate(key, texts: examples.map(\.meaning), source: kanjiExampleSource(examples), manual: false, id: id, legacy: legacy)
    }
    func retranslateKanjiExamples(_ card: KanjiCard, language: MeaningLanguage) {
        guard language == .russian else { return }
        let key = TranslationBlockKey.kanjiExamples(card.id)
        runManual(key, kind: .manualTranslation) { id in
            let examples: [KanjiExample]
            if let loaded = self.kanjiUsageExamples[card.id] { examples = loaded }
            else { examples = await KanjiDataLoader.loadExamplesIfNeeded(card, provider: self.kanjiProvider).englishExamples }
            guard self.current(id, key: key) else { return }
            self.kanjiUsageExamples[card.id] = examples
            await self.translate(key, texts: examples.map(\.meaning), source: self.kanjiExampleSource(examples), manual: true, id: id)
        }
    }
    func reloadKanjiExamples(_ card: KanjiCard, language: MeaningLanguage) {
        let key = TranslationBlockKey.kanjiExamples(card.id)
        runManual(key, kind: .manualExamples) { id in
            let examples = await KanjiDataLoader.reloadExamples(for: card, provider: self.kanjiProvider).englishExamples
            guard self.current(id, key: key), !examples.isEmpty else { return }
            self.kanjiUsageExamples[card.id] = examples
            if language == .russian {
                await self.translate(key, texts: examples.map(\.meaning), source: self.kanjiExampleSource(examples), manual: true, id: id)
            }
        }
    }
}
