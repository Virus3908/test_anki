import Foundation

extension TranslationViewModel {
    func displayedKanjiMeanings(for card: KanjiCard, language: MeaningLanguage) -> [String] {
        switch language {
        case .russian:
            return translatedTexts[.kanjiMeaning(card.kanji)] ?? card.cachedRussianMeanings ?? card.englishMeanings
        case .english:
            return card.englishMeanings
        }
    }

    func displayedKanjiExamples(for card: KanjiCard, language: MeaningLanguage) -> [KanjiExample] {
        let examples = originalKanjiExamples(for: card)
        switch language {
        case .russian:
            return kanjiExampleTranslations[card.kanji] ?? card.cachedRussianExamples ?? examples
        case .english:
            return examples
        }
    }

    func originalKanjiExamples(for card: KanjiCard) -> [KanjiExample] {
        kanjiUsageExamples[card.kanji] ?? card.englishExamples
    }

    func translateKanjiMeaningsIfNeeded(
        for card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) async {
        let key = TranslationBlockKey.kanjiMeaning(card.kanji)
        guard language == .russian,
              translatedTexts[key] == nil,
              !card.hasRussianMeanings,
              !automaticTranslationBlocks.contains(key),
              !manualTranslationBlocks.contains(key) else {
            if translatedTexts[key] == nil, let cachedMeanings = card.cachedRussianMeanings, !cachedMeanings.isEmpty {
                translatedTexts[key] = cachedMeanings
            }
            return
        }

        automaticTranslationBlocks.insert(key)
        defer { automaticTranslationBlocks.remove(key) }
        let meanings = await RussianMeaningTranslator.translateAutomatically(card.englishMeanings)
        guard !manualTranslationBlocks.contains(key),
              hasDifferentStrings(meanings, comparedTo: card.englishMeanings) else {
            return
        }

        translatedTexts[key] = meanings
        TranslationRepository.saveKanjiMeaningTranslation(meanings, for: card.kanji)
    }

    func translateKanjiExamplesIfNeeded(
        for card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) async -> KanjiCard? {
        let key = TranslationBlockKey.kanjiExamples(card.kanji)
        guard language == .russian,
              needsKanjiExampleTranslation(for: card),
              !automaticTranslationBlocks.contains(key),
              !manualTranslationBlocks.contains(key) else {
            return nil
        }

        automaticTranslationBlocks.insert(key)
        defer { automaticTranslationBlocks.remove(key) }
        let loadedCard = await KanjiDataLoader.loadExamplesIfNeeded(card)
        guard !manualTranslationBlocks.contains(key) else {
            return nil
        }

        let translatedExamples = await translateKanjiExamples(loadedCard.englishExamples)
        guard hasDifferentKanjiExamples(translatedExamples, comparedTo: loadedCard.englishExamples) else {
            return loadedCard
        }

        let translatedCard = loadedCard.withRussianExamples(translatedExamples)
        TranslationRepository.saveKanjiTranslation(from: translatedCard)
        return translatedCard
    }

    func loadKanjiExamplesIfNeeded(
        for card: KanjiCard,
        language: MeaningLanguage
    ) async {
        let key = TranslationBlockKey.kanjiExamples(card.kanji)
        guard kanjiUsageExamples[card.kanji] == nil,
              !automaticTranslationBlocks.contains(key),
              !manualTranslationBlocks.contains(key),
              !manualExampleReloadingBlocks.contains(key) else {
            return
        }

        automaticTranslationBlocks.insert(key)
        defer { automaticTranslationBlocks.remove(key) }

        let loadedCard = await KanjiDataLoader.loadExamplesIfNeeded(card)
        let examples = loadedCard.englishExamples
        guard !manualTranslationBlocks.contains(key),
              !manualExampleReloadingBlocks.contains(key) else {
            return
        }

        kanjiUsageExamples[card.kanji] = examples

        guard language == .russian, !examples.isEmpty else {
            return
        }

        let translatedExamples = await translateKanjiExamples(examples)
        guard !manualTranslationBlocks.contains(key),
              !manualExampleReloadingBlocks.contains(key),
              hasDifferentKanjiExamples(translatedExamples, comparedTo: examples) else {
            return
        }

        kanjiExampleTranslations[card.kanji] = translatedExamples
        TranslationRepository.saveKanjiTranslation(from: loadedCard.withRussianExamples(translatedExamples))
    }

    private func needsKanjiExampleTranslation(for card: KanjiCard) -> Bool {
        card.englishExamples.isEmpty || !card.hasRussianExamples
    }

    func retranslateKanjiMeanings(
        _ card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) {
        let key = TranslationBlockKey.kanjiMeaning(card.kanji)
        guard language == .russian,
              !manualTranslationBlocks.contains(key) else {
            return
        }

        manualTranslationBlocks.insert(key)

        Task { @MainActor in
            defer { manualTranslationBlocks.remove(key) }
            let meanings = await RussianMeaningTranslator.translateManual(card.englishMeanings)
            translatedTexts[key] = meanings
            TranslationRepository.saveKanjiMeaningTranslation(meanings, for: card.kanji)
        }
    }

    func retranslateKanjiExamples(
        _ card: KanjiCard,
        language: MeaningLanguage
    ) {
        let key = TranslationBlockKey.kanjiExamples(card.kanji)
        guard language == .russian,
              !manualTranslationBlocks.contains(key) else {
            return
        }

        manualTranslationBlocks.insert(key)

        Task { @MainActor in
            defer { manualTranslationBlocks.remove(key) }
            let loadedCard = await KanjiDataLoader.loadExamplesIfNeeded(card)
            let examples = loadedCard.englishExamples
            kanjiUsageExamples[card.kanji] = examples
            guard !examples.isEmpty else {
                kanjiExampleTranslations[card.kanji] = nil
                return
            }

            let translatedExamples = await translateKanjiExamples(examples, manual: true)
            kanjiExampleTranslations[card.kanji] = translatedExamples
            TranslationRepository.saveKanjiTranslation(from: loadedCard.withRussianExamples(translatedExamples))
        }
    }

    func reloadKanjiExamples(_ card: KanjiCard, language: MeaningLanguage) {
        let key = TranslationBlockKey.kanjiExamples(card.kanji)
        guard !manualExampleReloadingBlocks.contains(key),
              !manualTranslationBlocks.contains(key) else {
            return
        }

        manualExampleReloadingBlocks.insert(key)

        Task { @MainActor in
            defer { manualExampleReloadingBlocks.remove(key) }
            let loadedCard = await KanjiDataLoader.reloadExamples(for: card)
            let examples = loadedCard.englishExamples
            guard !manualTranslationBlocks.contains(key) else {
                return
            }

            kanjiUsageExamples[card.kanji] = examples
            kanjiExampleTranslations[card.kanji] = nil

            guard language == .russian, !examples.isEmpty else {
                return
            }

            let translatedExamples = await translateKanjiExamples(examples, manual: true)
            guard !manualTranslationBlocks.contains(key) else {
                return
            }

            kanjiExampleTranslations[card.kanji] = translatedExamples
            TranslationRepository.saveKanjiTranslation(from: loadedCard.withRussianExamples(translatedExamples))
        }
    }

    private func translateKanjiExamples(_ examples: [KanjiExample]) async -> [KanjiExample] {
        await translateKanjiExamples(examples, manual: false)
    }

    private func translateKanjiExamples(_ examples: [KanjiExample], manual: Bool) async -> [KanjiExample] {
        let sourceMeanings = examples.map(\.meaning)
        let translatedMeanings = manual
            ? await RussianMeaningTranslator.translatePreservingOrderManual(sourceMeanings)
            : await RussianMeaningTranslator.translateAutomatically(sourceMeanings)
        return examples.enumerated().map { index, example in
            KanjiExample(
                word: example.word,
                reading: example.reading,
                meaning: translatedMeanings[safe: index] ?? example.meaning
            )
        }
    }

    private func hasDifferentStrings(_ translated: [String], comparedTo source: [String]) -> Bool {
        zip(translated, source).contains { translatedItem, sourceItem in
            translatedItem.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(sourceItem.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
        }
    }

    private func hasDifferentKanjiExamples(_ translated: [KanjiExample], comparedTo source: [KanjiExample]) -> Bool {
        guard translated.count == source.count else {
            return true
        }

        return zip(translated, source).contains { translatedExample, sourceExample in
            translatedExample.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(sourceExample.meaning.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
        }
    }
}
