import Foundation

extension TranslationViewModel {
    func originalWordUsageExamples(for card: WordStudyCard) -> [WordUsageExample] {
        wordUsageExamples[card.id] ?? card.examples
    }

    func displayedWordUsageExamples(for card: WordStudyCard, language: MeaningLanguage) -> [WordUsageExample] {
        let examples = originalWordUsageExamples(for: card)
        switch language {
        case .russian:
            guard let translatedExamples = wordExampleTranslations[card.id], !translatedExamples.isEmpty else {
                return examples
            }

            return translatedExamples
        case .english:
            return examples
        }
    }

    func translateWordExamplesIfNeeded(
        for card: WordStudyCard,
        examples: [WordUsageExample],
        language: MeaningLanguage
    ) async {
        guard language == .russian,
              wordExampleTranslations[card.id] == nil,
              !examples.isEmpty else {
            return
        }

        let translatedExamples = await translateWordUsageExamples(examples)
        guard wordExampleTranslations[card.id] == nil else {
            return
        }

        wordExampleTranslations[card.id] = translatedExamples
        TranslationRepository.saveWordExampleTranslation(translatedExamples, for: card.id)
    }

    func retranslateWordExamples(_ card: WordStudyCard, language: MeaningLanguage) {
        guard language == .russian, !retranslationWordExampleKeys.contains(card.id) else {
            return
        }

        let examples = originalWordUsageExamples(for: card)
        guard !examples.isEmpty else {
            return
        }

        retranslationWordExampleKeys.insert(card.id)

        Task { @MainActor in
            let translatedExamples = await translateWordUsageExamples(examples)
            wordExampleTranslations[card.id] = translatedExamples
            TranslationRepository.saveWordExampleTranslation(translatedExamples, for: card.id)
            retranslationWordExampleKeys.remove(card.id)
        }
    }

    func loadWordUsageExamplesIfNeeded(for card: WordStudyCard) async {
        guard wordUsageExamples[card.id] == nil, !loadingWordExampleKeys.contains(card.id) else {
            return
        }

        loadingWordExampleKeys.insert(card.id)
        let examples = await WordUsageExampleProvider.loadExamples(for: card)
        wordUsageExamples[card.id] = examples
        loadingWordExampleKeys.remove(card.id)
    }

    func reloadWordUsageExamples(for card: WordStudyCard, language: MeaningLanguage) {
        guard !loadingWordExampleKeys.contains(card.id) else {
            return
        }

        loadingWordExampleKeys.insert(card.id)

        Task { @MainActor in
            let examples = await WordUsageExampleProvider.reloadRemoteExamples(for: card)
            if !examples.isEmpty {
                wordUsageExamples[card.id] = examples
                wordExampleTranslations[card.id] = nil

                if language == .russian {
                    let translatedExamples = await translateWordUsageExamples(examples)
                    wordExampleTranslations[card.id] = translatedExamples
                    TranslationRepository.saveWordExampleTranslation(translatedExamples, for: card.id)
                }
            }

            loadingWordExampleKeys.remove(card.id)
        }
    }

    func translateWordUsageExamples(_ examples: [WordUsageExample]) async -> [WordUsageExample] {
        let indexesAndMeanings = examples.enumerated().compactMap { index, example -> (Int, String)? in
            guard let meaning = example.meaning?.trimmingCharacters(in: .whitespacesAndNewlines), !meaning.isEmpty else {
                return nil
            }

            return (index, meaning)
        }

        guard !indexesAndMeanings.isEmpty else {
            return examples
        }

        let translatedMeanings = await RussianMeaningTranslator.translate(indexesAndMeanings.map(\.1))
        var translatedByIndex: [Int: String] = [:]
        for (translationIndex, source) in indexesAndMeanings.enumerated() {
            translatedByIndex[source.0] = translatedMeanings[safe: translationIndex] ?? source.1
        }

        return examples.enumerated().map { index, example in
            WordUsageExample(
                sentence: example.sentence,
                reading: example.reading,
                meaning: translatedByIndex[index] ?? example.meaning
            )
        }
    }
}
