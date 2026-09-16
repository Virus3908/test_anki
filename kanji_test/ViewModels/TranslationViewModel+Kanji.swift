import Foundation

extension TranslationViewModel {
    func displayedKanjiMeanings(for card: KanjiCard, language: MeaningLanguage) -> [String] {
        switch language {
        case .russian:
            return card.cachedRussianMeanings ?? card.englishMeanings
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
    ) async -> KanjiCard? {
        guard language == .russian,
              !card.hasRussianMeanings,
              !translationKanjiMeaningKeys.contains(card.kanji),
              !retranslationKanjiMeaningKeys.contains(card.kanji) else {
            return nil
        }

        translationKanjiMeaningKeys.insert(card.kanji)
        defer { translationKanjiMeaningKeys.remove(card.kanji) }
        let meanings = await RussianMeaningTranslator.translateAutomatically(card.englishMeanings)
        guard !retranslationKanjiMeaningKeys.contains(card.kanji),
              hasDifferentStrings(meanings, comparedTo: card.englishMeanings) else {
            return nil
        }

        let translatedCard = card.withRussianMeanings(meanings)
        TranslationRepository.saveKanjiTranslation(from: translatedCard)
        return translatedCard
    }

    func translateKanjiExamplesIfNeeded(
        for card: KanjiCard,
        deck: KanjiDeck,
        language: MeaningLanguage
    ) async -> KanjiCard? {
        guard language == .russian,
              needsKanjiExampleTranslation(for: card),
              !translationKanjiExampleKeys.contains(card.kanji),
              !retranslationKanjiExampleKeys.contains(card.kanji) else {
            return nil
        }

        translationKanjiExampleKeys.insert(card.kanji)
        defer { translationKanjiExampleKeys.remove(card.kanji) }
        let loadedCard = await KanjiDataLoader.loadExamplesIfNeeded(card)
        guard !retranslationKanjiExampleKeys.contains(card.kanji) else {
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
        guard kanjiUsageExamples[card.kanji] == nil,
              !translationKanjiExampleKeys.contains(card.kanji),
              !retranslationKanjiExampleKeys.contains(card.kanji),
              !reloadingKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        translationKanjiExampleKeys.insert(card.kanji)
        defer { translationKanjiExampleKeys.remove(card.kanji) }

        let loadedCard = await KanjiDataLoader.loadExamplesIfNeeded(card)
        let examples = loadedCard.englishExamples
        guard !retranslationKanjiExampleKeys.contains(card.kanji),
              !reloadingKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        kanjiUsageExamples[card.kanji] = examples

        guard language == .russian, !examples.isEmpty else {
            return
        }

        let translatedExamples = await translateKanjiExamples(examples)
        guard !retranslationKanjiExampleKeys.contains(card.kanji),
              !reloadingKanjiExampleKeys.contains(card.kanji),
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
        language: MeaningLanguage,
        onTranslated: @MainActor @escaping (KanjiCard) -> Void
    ) {
        guard language == .russian,
              !retranslationKanjiMeaningKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiMeaningKeys.insert(card.kanji)

        Task { @MainActor in
            defer { retranslationKanjiMeaningKeys.remove(card.kanji) }
            let meanings = await RussianMeaningTranslator.translateManual(card.englishMeanings)
            let translatedCard = card.withRussianMeanings(meanings)
            TranslationRepository.saveKanjiTranslation(from: translatedCard)
            onTranslated(translatedCard)
        }
    }

    func retranslateKanjiExamples(
        _ card: KanjiCard,
        language: MeaningLanguage
    ) {
        guard language == .russian,
              !retranslationKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        retranslationKanjiExampleKeys.insert(card.kanji)

        Task { @MainActor in
            defer { retranslationKanjiExampleKeys.remove(card.kanji) }
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
        guard !reloadingKanjiExampleKeys.contains(card.kanji),
              !retranslationKanjiExampleKeys.contains(card.kanji) else {
            return
        }

        reloadingKanjiExampleKeys.insert(card.kanji)

        Task { @MainActor in
            defer { reloadingKanjiExampleKeys.remove(card.kanji) }
            let loadedCard = await KanjiDataLoader.reloadExamples(for: card)
            let examples = loadedCard.englishExamples
            guard !retranslationKanjiExampleKeys.contains(card.kanji) else {
                return
            }

            kanjiUsageExamples[card.kanji] = examples
            kanjiExampleTranslations[card.kanji] = nil

            guard language == .russian, !examples.isEmpty else {
                return
            }

            let translatedExamples = await translateKanjiExamples(examples, manual: true)
            guard !retranslationKanjiExampleKeys.contains(card.kanji) else {
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
