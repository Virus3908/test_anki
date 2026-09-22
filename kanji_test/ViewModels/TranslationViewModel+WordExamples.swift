import Foundation

extension TranslationViewModel {
    func originalWordUsageExamples(for card: WordStudyCard) -> [WordUsageExample] { wordUsageExamples[card.id] ?? card.examples }
    func wordExampleSource(_ examples: [WordUsageExample]) -> [String] {
        examples.flatMap { [$0.sentence, $0.reading ?? "", $0.meaning ?? ""] }
    }
    func displayedWordUsageExamples(for card: WordStudyCard, language: MeaningLanguage) -> [WordUsageExample] {
        let examples = originalWordUsageExamples(for: card)
        guard language == .russian, let meanings = cached(.wordExamples(card.id), source: wordExampleSource(examples)),
              meanings.count == examples.count else { return examples }
        return zip(examples, meanings).map { example, meaning in
            WordUsageExample(sentence: example.sentence, reading: example.reading,
                             meaning: meaning.isEmpty ? nil : meaning, attribution: example.attribution)
        }
    }
    func loadAndTranslateWordExamples(for card: WordStudyCard, language: MeaningLanguage) async {
        let key = TranslationBlockKey.wordExamples(card.id)
        guard let id = beginAutomatic(key, kind: .automaticExamples) else { return }
        defer { end(id, key: key) }
        let examples: [WordUsageExample]
        if let loaded = wordUsageExamples[card.id] { examples = loaded }
        else { examples = await wordProvider.loadExamples(for: card, limit: 3) }
        guard current(id, key: key) else { return }
        wordUsageExamples[card.id] = examples
        guard language == .russian else { return }
        let old = store.legacy.wordExampleTranslations[card.id]
        let legacy = old?.map(\.sentence) == examples.map(\.sentence) && old?.map(\.reading) == examples.map(\.reading)
            ? old?.map { $0.meaning ?? "" } : nil
        await translate(key, texts: examples.map { $0.meaning ?? "" },
                        source: wordExampleSource(examples), manual: false, id: id, legacy: legacy)
    }
    func retranslateWordExamples(_ card: WordStudyCard, language: MeaningLanguage) {
        guard language == .russian else { return }
        let key = TranslationBlockKey.wordExamples(card.id)
        let examples = originalWordUsageExamples(for: card)
        runManual(key, kind: .manualTranslation) { id in
            await self.translate(key, texts: examples.map { $0.meaning ?? "" }, source: self.wordExampleSource(examples), manual: true, id: id)
        }
    }
    func reloadWordUsageExamples(for card: WordStudyCard, language: MeaningLanguage) {
        let key = TranslationBlockKey.wordExamples(card.id)
        runManual(key, kind: .manualExamples) { id in
            let examples = await self.wordProvider.reloadRemoteExamples(for: card, limit: 3)
            guard self.current(id, key: key), !examples.isEmpty else { return }
            self.wordUsageExamples[card.id] = examples
            if language == .russian {
                await self.translate(key, texts: examples.map { $0.meaning ?? "" }, source: self.wordExampleSource(examples), manual: true, id: id)
            }
        }
    }
}
